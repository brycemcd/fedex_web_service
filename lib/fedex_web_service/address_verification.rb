class FedexWebService
  class AddressVerification < FedexWebService
    #receives an order_info object and parses it into a verification request. Returns an AddressVerificationResponse (object)
    def verify_address(order)
      puts wsdl = wsdl = File.expand_path( RAILS_ROOT + "/lib/wsdl/" + @default_options[:av_wsdl] )
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
                  :changedPostal

    def initialize(soap_response)
      self.responseString           = soap_response.notifications.severity
      self.changes                  = soap_response.addressResults.proposedAddressDetails.changes
      self.deliveryPointValidation  = soap_response.addressResults.proposedAddressDetails.deliveryPointValidation
      self.score                    = soap_response.addressResults.proposedAddressDetails.score.to_i
      self.residentialStatus        = soap_response.addressResults.proposedAddressDetails.residentialStatus
      self.changedAddress           = soap_response.addressResults.proposedAddressDetails.address.streetLines.to_s
      self.changedCity              = soap_response.addressResults.proposedAddressDetails.address.city
      self.changedState             = soap_response.addressResults.proposedAddressDetails.address.stateOrProvinceCode
      self.changedPostal            = soap_response.addressResults.proposedAddressDetails.address.postalCode
    end
  end
end