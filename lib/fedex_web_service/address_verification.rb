class FedexWebService
  class AddressVerification < FedexWebService
    #receives an order_info object and parses it into a verification request. Returns an AddressVerificationResponse (object)
    def verify_address(order)
      puts wsdl = wsdl = File.expand_path( RAILS_ROOT + "/lib/wsdl/" + @fedex_conf[:av_wsdl] )
      driver = SOAP::WSDLDriverFactory.new(wsdl).create_rpc_driver
    
      call = { :WebAuthenticationDetail => {
                  :UserCredential => {
                    :Key => @key, 
                    :Password => @password
                  } 
                },
          :ClientDetail => {
            :AccountNumber => @accountnumber, 
            :MeterNumber => @meternumber 
          },
          :TransactionDetail => {
            :CustomerTransactionId => "WSVC_addressvalidation"
          },
          :Version => {:ServiceId => 'aval', :Major => '2', :Intermediate => '0', :Minor => '0'},
          :RequestTimestamp => self.fedex_time_stamp(),
          :Options => {
            :VerifyAddresses => 1,
            :CheckResidentialStatus => 1
          },
          :AddressesToValidate => 
            [:Address => {
              :CountryCode => 'US',
              :StreetLines => order.shipping_address_1,
              :City => order.shipping_city,
              :StateOrProvinceCode => order.shipping_state,
              :PostalCode => order.shipping_zip,
              :Residential => true
            }]
        
        }
     
      result = driver.addressValidation(call)
      AddressVerificationResponse.new(result)
    end
  end #end Class AddressVerification
  
  class AddressVerificationResponse
    # this is really just a data translation object. It receives a SOAP response (blech) and translates it into a Ruby 
    # object. Where it's not blindingly obvious, I've included notes for each attribute
    
    attr_accessor :responseString, 
                  :deliveryPointValidation, #is either CONFIRMED, UNCONFIRMED, UNAVAILABLE
                  :changes,
                  :score, #the score Fedex gives it based on how confident they are 0..100 
                  :residentialStatus, #one of UNDETERMINED, BUSINESS, RESIDENTIAL, INSUFFICIENT_DATA, UNAVAILABLE, NOT_APPLICABLE_TO_COUNTRY
                  :changedAddress, #address streetlines, modified by Fedex
                  :changedCity,
                  :changedState,
                  :changedPostal,
                  :responses

    def initialize(soap_response)
        @soap_response = soap_response #so we can use it with other methods in this class

        address_results = address_results_an_array? ? @soap_response.addressResults.proposedAddressDetails[0] : @soap_response.addressResults.proposedAddressDetails

        self.responseString           = soap_response.notifications.severity
        self.changes                  = address_results.changes
        self.deliveryPointValidation  = address_results.deliveryPointValidation
        self.score                    = address_results.score.to_i
        self.residentialStatus        = address_results.residentialStatus 
        self.changedAddress           = address_results.address.streetLines.to_s
        self.changedCity              = address_results.address.city
        self.changedState             = address_results.address.stateOrProvinceCode
        self.changedPostal            = address_results.address.postalCode
        self.responses                = []

        set_other_responses if address_results_an_array?

      end

      protected

      def set_other_responses

          @soap_response.addressResults.proposedAddressDetails.each do |address_results|
            response = {}
            response[:changes]                  = address_results.changes
            response[:deliveryPointValidation]  = address_results.deliveryPointValidation
            response[:score]                    = address_results.score.to_i
            response[:residentialStatus]        = address_results.residentialStatus 
            response[:changedAddress]           = address_results.address.streetLines.to_s
            response[:changedCity]              = address_results.address.city
            response[:changedState]             = address_results.address.stateOrProvinceCode
            response[:changedPostal]            = address_results.address.postalCode
            self.responses << response
          end
      end

      def address_results_an_array?
        @soap_response.addressResults.proposedAddressDetails.is_a?(Array)
      end
  end
end