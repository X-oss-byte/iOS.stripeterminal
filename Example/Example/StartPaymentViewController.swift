//
//  StartPaymentViewController.swift
//  Example
//
//  Created by Ben Guo on 9/6/18.
//  Copyright © 2018 Stripe. All rights reserved.
//

import UIKit
import Static
import StripeTerminal

class StartPaymentViewController: TableViewController, CancelingViewController {

    private let amountView = AmountInputView()
    private let currencyView = CurrencyInputView()
    private var startSection: Section?
    private var interacPresentEnabled = false
    private var setupFutureUsage: String?

    private var connectedAccountId: String {
        connectedAccountTextField.textField.text ?? ""
    }

    private let connectedAccountTextField = TextFieldView(
        placeholderText: "Connected Stripe Account ID")

    private var connectedReaderIsBluetoothReader: Bool {
        [DeviceType.stripeM2,
         DeviceType.chipper2X,
         DeviceType.wisePad3].contains(Terminal.shared.connectedReader?.deviceType)
    }

    convenience init() {
        self.init(style: .grouped)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.addKeyboardDisplayObservers()

        title = "Collect card payment"

        connectedAccountTextField.textField.autocorrectionType = .no
        connectedAccountTextField.textField.autocapitalizationType = .none
        connectedAccountTextField.textField.delegate = self
        connectedAccountTextField.textField.clearButtonMode = .whileEditing

        amountView.onAmountUpdated = { [unowned self] amountString in
            self.startSection?.header = Section.Extremity.title(amountString)
            self.updateContent()
        }

        currencyView.onCurrencyUpdated = { [unowned self] currencyString in
            self.amountView.numberFormatter.currencyCode = currencyString
            self.startSection?.header = Section.Extremity.title(self.amountView.amountString)
            self.updateContent()
        }

        let headerString: String
        if ReaderViewController.readerConfiguration.simulated {
            headerString = "Collect a card payment using a simulated reader."
        } else {
            let readerString: String = {
                if let reader = Terminal.shared.connectedReader {
                    return "the \(Terminal.stringFromDeviceType(reader.deviceType))"
                } else {
                    return "reader"
                }
            }()
            headerString = "Collect a card payment using a physical Stripe test card and \(readerString)"
        }
        self.startSection = Section(header: Section.Extremity.title(self.amountView.amountString), rows: [
            Row(text: "Collect payment", selection: { [unowned self] in
                self.startPayment()
                }, cellClass: ButtonCell.self)
        ], footer: Section.Extremity.title(headerString))

        updateContent()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // pop if no reader is connected
        guard Terminal.shared.connectedReader != nil else {
            navigationController?.popViewController(animated: true)
            return
        }
        amountView.textField.becomeFirstResponder()
    }

    // MARK: - UIAdaptivePresentationControllerDelegate

    // See comment in `CancelingViewController` for why we're canceling during `ShouldDismiss` instead of `DidDismiss`
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        performCancel(presentationController: presentationController)
        return true
    }

    // MARK: - Internal

    internal func startPayment() {
        var paymentMethodTypes = ["card_present"]

        if self.interacPresentEnabled {
            paymentMethodTypes.append("interac_present")
        }

        let paymentParams = PaymentIntentParameters(amount: amountView.amount,
                                                    currency: currencyView.currency,
                                                    paymentMethodTypes: paymentMethodTypes)

        paymentParams.setupFutureUsage = self.setupFutureUsage

        // Set up destination payment
        if !connectedAccountId.isEmpty {
            paymentParams.transferDataDestination = connectedAccountId
            paymentParams.onBehalfOf = connectedAccountId
        }

        let vc = PaymentViewController(paymentParams: paymentParams)
        let navController = LargeTitleNavigationController(rootViewController: vc)
        navController.presentationController?.delegate = self
        self.present(navController, animated: true, completion: nil)
    }

    private func makeAmountSection() -> Section {
        Section(
            header: "AMOUNT",
            rows: [],
            footer: Section.Extremity.autoLayoutView(amountView))
    }

    private func makeCurrencySection() -> Section {
        Section(
            header: "CURRENCY",
            rows: [],
            footer: Section.Extremity.autoLayoutView(currencyView))
    }

    private func makePaymentMethodSection() -> Section {
        let shouldShowTestCardPickerView = Terminal.shared.connectedReader?.simulated == true && connectedReaderIsBluetoothReader

        let paymentMethodSection = Section(header: Section.Extremity.title("Payment Method"), rows: [
            Row(text: "Enable Interac Present", accessory: .switchToggle(value: self.interacPresentEnabled) { [unowned self] _ in
                self.interacPresentEnabled.toggle()
            })
        ], footer: shouldShowTestCardPickerView ? Section.Extremity.autoLayoutView(TestCardPickerView()) : nil)

        return paymentMethodSection
    }

    /// Makes the "SETUP FUTURE USAGE" section.
    /// - Returns: A `Section` if the connected reader is a bluetooth reader. `nil` otherwise.
    private func makeSetupFutureUsageSection() -> Section? {
        guard connectedReaderIsBluetoothReader else { return nil }
        let rows: [Row] = [
            Row(text: "Value",
                accessory: .segmentedControl(
                    items: ["default", "on_session", "off_session"],
                    selectedIndex: 0) { [unowned self] newIndex, _ in
                        switch newIndex {
                        case 0: self.setupFutureUsage = nil
                        case 1: self.setupFutureUsage = "on_session"
                        case 2: self.setupFutureUsage = "off_session"
                        default:
                            fatalError("Unknown option selected")
                        }
                    }
               )
        ]

        return Section(header: "SETUP FUTURE USAGE", rows: rows)
    }

    func makeDestinationPaymentSection() -> Section {

        let destinationPaymentSection = Section(
            header: "Destination Payment",
            rows: [],
            footer: Section.Extremity.autoLayoutView(connectedAccountTextField)
        )

        return destinationPaymentSection
    }

    private func updateContent() {

        var sections: [Section] = [
            self.makeAmountSection(),
            self.makeCurrencySection(),
            self.makePaymentMethodSection(),
            self.makeDestinationPaymentSection()
        ]

        if let setupFutureUsageSection = self.makeSetupFutureUsageSection() {
            sections.append(setupFutureUsageSection)
        }

        if let startSection = self.startSection {
            sections.append(startSection)
        }

        dataSource.sections = sections
    }
}


extension StartPaymentViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
