module DataImport::Readers
  class HashStrategy
    include DataImport::Errors
    attr_reader :errors

    def initialize(data_object)
      @data_object = data_object
      @errors = []
    end

    def read_file
      if data_object
        data_object
      else
        errors << data_not_present_error
        nil
      end
    end

    private

    attr_reader :data_object
  end
end
