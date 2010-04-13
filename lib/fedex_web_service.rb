require "soap/wsdlDriver" #FIXME MAKE SURE TO REMOVE NEW VERSIONS OF SOAP4R 1.5.5 is the last version that is supported here
require 'xmlrpc/client'
require 'net/ftp'

require "services/address_verification"
    
class FedexWebService
  attr_accessor :tracking_number, :label, :full_response, :temp_image
  
  # There are three types of options designed to save keystokes. Gem default options are the options I use for this particular project
  # I'm working on. These are easily overridden by providing options of the same name in the config/fedex_config.yml file. This will set
  # the options per project. If you want to change the options PER LABEL, then just pass them in when you call the method
  #
  # EX: if you want to default residential to false for this project, then the yml file would look like:
  # common: &testing
  #     key: lotsoflettersandnumbers
  #     ....
  #     defaults:
  #         residential: false
  
  
  @@gem_default_options ={
    :drop_off_type      => "REGULAR_PICKUP",
    :residential        => true,
    :label              => 'RESIDENTIAL',
    :drop_off_type      => 'REGULAR_PICKUP',
    :packaging_type     => 'YOUR_PACKAGING',
    :label_format_type  => 'COMMON2D',
    :label_stock_type   => 'PAPER_4X6',
    :image_type         => "PNG",
    :dimensions         => {:length => 5, :width => 5, :height => 5}
  }
  def initialize
    raw_config = File.read(RAILS_ROOT + "/config/fedex_config.yml")
    @fedex_conf = YAML.load(raw_config)[RAILS_ENV].symbolize_keys
    
    @key            = @fedex_conf[:key]
    @password       = @fedex_conf[:password]
    @accountnumber  = @fedex_conf[:accountnumber]
    @meternumber    = @fedex_conf[:meternumber]
    @ss_wsdl        = @fedex_conf[:ss_wsdl]
    @default_options= @@gem_default_options.merge( @fedex_conf[:defaults] )
  end
  
  def future_shipment(address_info, options = {})
    # this method sends a request to Fedex to get the future shipment date, a tracking number and the image file of a label
    # the method returns the tracking number as a result to show that the request was done correctly, those class attributes
    # are set to include the tracking number, the label (img) and the full response (SOAP object ... yech)
      
    options = self.default_options.merge( options )
    
    wsdl = File.expand_path( RAILS_ROOT + 'lib/wsdl/' + self.ss_wsdl )
    driver = build_wsdl_driver(wsdl)
    

    call = {:WebAuthenticationDetail => {:UserCredential => {:Key => @key, :Password => @password} },
      :ClientDetail => {:AccountNumber => @accountnumber, :MeterNumber => @meternumber },
      :TransactionDetail=> {:CustomerTransactionId => '*** Ground Domestic Shipping Request v7' },
      :Version => {:ServiceId => 'ship', :Major => '7', :Intermediate => '0', :Minor => '0'},
      :RequestedShipment => {
      :ShipTimestamp => "#{3.days.from_now.strftime("%Y-%m-%d")}T9:00:00-07:00", 
      :DropoffType => options[:drop_off_type],
      :ServiceType => options[:label], # 'FEDEX_2_DAY' 'FEDEX_GROUND' 'GROUND_HOME_DELIVERY'
      :PackagingType => options[:packaging_type], # valid values FEDEX_BOX, FEDEX_PAK, FEDEX_TUBE, YOUR_PACKAGING, ...
      :SpecialServicesRequested => {:SpecialServiceType => "FUTURE_DATE_SHIPMENT"},
      :Recipient => { #should have same address as Origin per docs
        :Contact => {
          :PersonName => address_info.first_name + " " + address_info.last_name,
          :PhoneNumber => phone #params[:phone] 
          
        },
        :Address => {
          :CountryCode => 'US',
          :StreetLines => address_info.shipping_address_1, #params[:shipAddress],
          :City => address_info.shipping_city, #params[:shipCity],
          :StateOrProvinceCode => address_info.shipping_state, #params[:shipState],
          :PostalCode => address_info.shipping_zip, #params[:shipZip]
          :Residential => options[:residential]
        }
      },
      :Shipper => {
        :Contact => {
          :PersonName =>  options[:person_name],
          :PhoneNumber => options[:phone_number]
        },
        :Address => {
          :CountryCode => 'US',
          :StreetLines => options[:address],
          :City => options[:city],
          :StateOrProvinceCode => options[:state],
          :PostalCode => options[:postal_code]
          #:Residential => TRUE
        }
      },
      :ShippingChargesPayment => {
        :PaymentType => 'SENDER',
        :Payor => {
          :AccountNumber => self.accountnumber,
          :CountryCode => 'US'
        }
      },
      :LabelSpecification => {
        :LabelFormatType => options[:label_format_type],
        :LabelStockType => options[:label_stock_type],
        :ImageType => options[:image_type], #// valid values DPL, EPL2, PDF, ZPLII and PNG
        :CustomerSpecifiedDetail => {:MaskedData => "SHIPPER_ACCOUNT_NUMBER"}
      },
      :RateRequestTypes => 'ACCOUNT', #, // valid values ACCOUNT and LIST
      :PackageCount => 1, 
      :PackageDetail => "INDIVIDUAL_PACKAGES",
      :RequestedPackageLineItems => [{
        :SequenceNumber=>1, 
        :Weight => { :Units => "LB", :Value => 1 },
        :Dimensions => {
          :Length => options[:dimensions][:length], 
          :Width => options[:dimensions][:width], 
          :Height => options[:dimensions][:height], 
          :Units => "IN"
        },
        :CustomerReferences => [{:CustomerReferenceType => "INVOICE_NUMBER", :Value => "#{options[:invoice_number]}"], #in a string so if it's empty it's just an empty string
      }]
    }
  }
    result = driver.processShipment(call)
    begin
      self.label = Base64.decode64(result.completedShipmentDetail.completedPackageDetails.label.parts.image)
      self.full_response = result
      self.tracking_number = result.completedShipmentDetail.completedPackageDetails.trackingIds.trackingNumber
    rescue  Exception => e
      #the FEDEX call returned an error
      self.label = "error"
      self.full_response = result
      self.tracking_number = "error"
    end
  end
  
  protected
  
  def build_wsdl_driver(wsdl)
    driver = SOAP::WSDLDriverFactory.new(wsdl).create_rpc_driver
  end
  
  def fedex_time_stamp
    "#{Time.now.year}-#{Time.now.month}-#{Time.now.day}T#{Time.now.hour}:#{Time.now.min}:#{Time.now.sec}-08:00"
  end
end

