module Griddler
  module Mailgun
    class Adapter
      attr_reader :params

      def initialize(params)
        @params = params
      end

      def self.normalize_params(params)
        adapter = new(params)
        adapter.normalize_params
      end

      def normalize_params
        {
          to: to_recipients,
          cc: cc_recipients,
          bcc: Array.wrap(param_or_header(:Bcc)),
          from: determine_sender,
          reply_to: param_or_header("Reply-To"),
          subject: params[:subject],
          text: params['body-plain'],
          html: params['body-html'],
          attachments: attachment_files,
          headers: serialized_headers,
          vendor_specific: {
            sender: params["sender"],
            stripped_text: params["stripped-text"],
            stripped_signature: params["stripped-signature"],
            stripped_html: params["stripped-html"],
            content_id_map: params["content-id-map"]
          }
        }
      end

    private

      def determine_sender
        sender = param_or_header(:From)
        sender ||= params[:sender]
      end

      def to_recipients
        to_emails = param_or_header(:To)
        to_emails ||= params[:recipient]
        to_emails.split(',').map(&:strip)
      end

      def cc_recipients
        cc = param_or_header(:Cc) || ''
        cc.split(',').map(&:strip)
      end

      def headers
        @headers ||= extract_headers
      end

      def extract_headers
        extracted_headers = {}
        if params['message-headers']
          parsed_headers = JSON.parse(params['message-headers'])
          parsed_headers.each{ |h| extracted_headers[h[0]] = h[1] }
        end
        ActiveSupport::HashWithIndifferentAccess.new(extracted_headers)
      end

      def serialized_headers

        # Griddler expects unparsed headers to pass to ActionMailer, which will manually
        # unfold, split on line-endings, and parse into individual fields.
        #
        # Mailgun already provides fully-parsed headers in JSON -- so we're reconstructing
        # fake headers here for now, until we can find a better way to pass the parsed
        # headers directly to Griddler

        headers.to_a.collect { |header| "#{header[0]}: #{header[1]}" }.join("\n")
      end

      def param_or_header(key)
        if params[key].present?
          params[key]
        elsif headers[key].present?
          headers[key]
        else
          nil
        end
      end

      def attachment_files
        if params["attachment-count"].present?
          attachment_count = params["attachment-count"].to_i

          attachment_count.times.map do |index|
            params.delete("attachment-#{index+1}")
          end
        else
          params["attachments"] || []
        end
      end
    end
  end
end
