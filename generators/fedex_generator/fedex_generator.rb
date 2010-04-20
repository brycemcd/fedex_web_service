class FedexGenerator < Rails::Generator::NamedBase
  
  def initialize(runtime_args, runtime_options = {})
      super
      #and only
      @name = runtime_args.first
  end
  
  
  def manifest
    record do |m|
      m.template "fedex.yml", "config/#{@name}.yml"
    end    
  end
end