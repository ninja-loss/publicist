module Publicist
  module Publisher

    def self.included( other_module )
      other_module.extend ClassMethods
    end

    module ClassMethods

      def publications
        @publications ||= []
      end

      def publishes( *publications )
        publications.each do |publication|
          self.publications << publication
          define_method publication do |*args|
            subscriptions[publication].each do |subscriber_proc|
              subscriber_proc.call( *args )
            end
          end
        end
        self
      end

    end

    #my_collaborator.subscribe :some_publication_name, subscriber_object
    #my_collaborator.subscribe :some_publication_name, jason,
                                                       #subscriber_object => :subscriber_method,
                                                       #another_subscriber => :his_method
    #my_collaborator.subscribe :some_publication_name, {subscriber_object => :subscriber_method,
                                                       #another_subscriber => :his_method}
    #my_collaborator.subscribe :log_event, Rails.logger => :warn
    #my_collaborator.subscribe :log_event do |options|
      ## Do something here on the event
      #Rails.logger.warn options[:message]
    #end
    #my_collaborator.subscribe :log_event, lambda { |options|
    #  Rails.logger.warn options[:message]
    #}, another_collaborator => :do_something
    #
    def subscribe!( publication, *subscribers, &last_subscriber )
      unless self.class.publications.include?( publication )
        raise ArgumentError.new( "#{self.class.name} does not publish #{publication.inspect}" )
      end

      subscribe( publication, *subscribers, &last_subscriber )
    end

    def subscribe( publication, *subscribers, &last_subscriber )
      redirected_subscribers = subscribers.extract_options!
      default_subscribers    = subscribers

      self.subscriptions[publication] ||= []

      default_subscribers.each do |subscriber_object_or_proc|
        subscriber_method = publication
        if subscriber_object_or_proc.respond_to?( subscriber_method )
          self.subscriptions[publication] << lambda { |*arguments|
            subscriber_object_or_proc.send( subscriber_method, *arguments )
          }
        elsif subscriber_object_or_proc.respond_to?( :call )
          self.subscriptions[publication] << subscriber_object_or_proc
        else
          raise ArgumentError.new( "Expected subscriber to respond to ##{subscriber_method} or #call" )
        end
      end
      self.subscriptions[publication] << last_subscriber if last_subscriber

      redirected_subscribers.each do |subscriber_object, subscriber_method|
        self.subscriptions[publication] << lambda { |*arguments|
          subscriber_object.send( subscriber_method, *arguments )
        }
      end
      self
    end

  protected

    def subscriptions
      @subscriptions ||= {}
    end

  end
end
