require 'aws-sdk'

AWS.config(:ssl_verify_peer => false)

module RedmineS3
  class Connection
    @@conn = nil
    @@s3_options = {
      :access_key_id     => ENV['S3_ACCESS_KEY'],
      :secret_access_key => ENV['S3_SECRET_KEY'],
      :bucket            => ENV['S3_BUCKET'],
      :folder            => ENV['S3_FOLDER'] || '',
      :endpoint          => ENV['S3_END_POINT'] || 's3-ap-northeast-1.amazonaws.com',
      :private           => ENV['S3_PRIVATE'] || true,
      :expires           => nil,
      :secure            => ENV['S3_SECURE'] || true,
      :proxy             => false,
      :thumb_folder      => 'tmp'
    }

    class << self
      def load_options
        file = ERB.new( File.read(File.join(Rails.root, 'config', 's3.yml')) ).result
        YAML::load( file )[Rails.env].each do |key, value|
          @@s3_options[key.to_sym] = value
        end
      end

      def establish_connection
        load_options unless @@s3_options[:access_key_id] && @@s3_options[:secret_access_key]
        options = {
          :access_key_id => @@s3_options[:access_key_id],
          :secret_access_key => @@s3_options[:secret_access_key]
        }
        options[:s3_endpoint] = self.endpoint unless self.endpoint.nil?
        @conn = AWS::S3.new(options)
      end

      def conn
        @@conn || establish_connection
      end

      def bucket
        load_options unless @@s3_options[:bucket]
        @@s3_options[:bucket]
      end

      def create_bucket
        bucket = self.conn.buckets[self.bucket]
        self.conn.buckets.create(self.bucket) unless bucket.exists?
      end

      def folder
        str = @@s3_options[:folder]
        if str.present?
          str.match(/\S+\//) ? str : "#{str}/"
        else
          ''
        end
      end

      def endpoint
        @@s3_options[:endpoint]
      end

      def expires
        @@s3_options[:expires]
      end

      def private?
        @@s3_options[:private]
      end

      def secure?
        @@s3_options[:secure]
      end

      def proxy?
        @@s3_options[:proxy]
      end

      def thumb_folder
        str = @@s3_options[:thumb_folder]
        if str.present?
          str.match(/\S+\//) ? str : "#{str}/"
        else
          'tmp/'
        end
      end

      def object(filename, target_folder = self.folder)
        bucket = self.conn.buckets[self.bucket]
        bucket.objects[target_folder + filename]
      end

      def put(disk_filename, original_filename, data, content_type='application/octet-stream', target_folder = self.folder)
        object = self.object(disk_filename, target_folder)
        options = {}
        options[:acl] = :public_read unless self.private?
        options[:content_type] = content_type if content_type
        options[:content_disposition] = "inline; filename=#{ERB::Util.url_encode(original_filename)}"
        object.write(data, options)
      end

      def delete(filename, target_folder = self.folder)
        object = self.object(filename, target_folder)
        object.delete
      end

      def object_url(filename, target_folder = self.folder)
        object = self.object(filename, target_folder)
        if self.private?
          options = {:secure => self.secure?}
          options[:expires] = self.expires unless self.expires.nil?
          object.url_for(:read, options).to_s
        else
          object.public_url(:secure => self.secure?).to_s
        end
      end

      def get(filename, target_folder = self.folder)
        object = self.object(filename, target_folder)
        object.read
      end
    end
  end
end
