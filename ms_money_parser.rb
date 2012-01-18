require "csv"

module MsMoney

  class Data

    attr_reader :file_path, :meta_data, :transactions

    def initialize(file_path, meta_data, transactions)
      @file_path = file_path
      @meta_data = meta_data
      @transactions = transactions
    end

  end

  class SimpleCsvDumper

    def self.dump(file_path, data)
      CSV.open(file_path, "wb") do |csv|
        data.meta_data.each do |label, value|
          csv << [label, value]
        end
        csv << []

        data.transactions.each do |row|
          csv << [row["DTPOSTED"].strftime("%Y-%m-%d %H:%M:%S"), row["MEMO"], row["NAME"], row["TRNAMT"]]
        end
      end
    end

  end

  class Parser

    class << self

      def parse(file_path)
        # parse meta data
        meta_data = parse_meta_data(file_path)
        
        # parse transactions log
        all_trx = File.read(file_path).scan(/<STMTTRN>(?:.|\n)*?<\/STMTTRN>/)
        transactions = all_trx.map{|trx| parse_trx(trx) }

        return MsMoney::Data.new(file_path, meta_data, transactions)
      end

      private

      def parse_meta_data(file_path)
        ret = {}
        File.foreach(file_path) do |line|
          break if line == "\n"
          label, value = line.chomp.split(":")
          ret[label] = value
        end
        return ret
      end
      
      def parse_trx(trx_line)
        ret = {}
        trx_line.chomp.gsub(/<\/?STMTTRN>/, "").scan(/<([^>]+)>(.*)\n/).each do |ary|
          label, value = ary
          value = value.to_i if value =~ /\A-?\d+\z/
          value = value.to_f if value =~ /\A-?\d+\.\d+\z/
          ret[label] = value
        end
        ret["DTPOSTED"] = parse_datetime(ret["DTPOSTED"])
        return ret
      end

      def parse_datetime(datetime)
        if datetime =~ /(\d{4})(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)\[([\+\-]?\d+(?:\.\d+)?)\:[a-zA-Z]+\]/ then
          # TODO: consider timezone?
          y, m, d = $1.to_i, $2.to_i, $3.to_i
          hour, min, sec = $4.to_i, $5.to_i, $6.to_i
          time_zone_diff = $7.to_i
          return Time.local(y, m, d, hour, min, sec)
        else
          return datetime
        end
      end

    end

  end

end
