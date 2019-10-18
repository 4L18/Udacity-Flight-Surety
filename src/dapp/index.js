
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {
    console.log('works');
    let result = null;
    let flight;
    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            console.log(error, result);
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });
    

        // User-submitted transaction
        DOM.elid('req-to-oracle').addEventListener('click', () => {
            console.log('submit oracle clicked');

            flight = DOM.elid('flight-number').value;
            console.log(flight);            
            
            contract.fetchFlightStatus(flight, (error, result) => {
                console.log('insideFFS' + JSON.stringify(result));
            });
        })

        

        DOM.elid('withdrawal-credit').addEventListener('click', (error, result) => {
            console.log('withdrawal credit clicked');

            let amount = DOM.elid('credit').value;

            contract.pay(flight, {value: amount}, (error, result) => {
                
                refundDiv.style.visibility = 'none';
                display('Withdrawal status', '', [ { label: 'Credit', error: error, value: result} ]);
                
                if(error) {
                    console.log(error);
                }
            });
        });

        DOM.elid('pay-insurance').addEventListener('click', (error, result) => {
            console.log('pay insurance clicked');
            
            let amount = DOM.elid('payment-amount').value;

            contract.pay(flight, {value: amount}, (error, result) => {
                
                payDiv.style.visibility = 'none';
                display('Payment status', 'The insurance has been paid', [ { label: 'Credit has been ', error: error, value: result} ]);

                if(error) {
                    console.log(error);
                }
            });
        });
    });
})();


function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);
}







