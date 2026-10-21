namespace :mpesa do
  desc "Compare a Safaricom statement CSV (receipt,amount) with recorded C2B or B2C transactions"
  task reconcile: :environment do
    kind = ENV.fetch("KIND")
    file = ENV.fetch("FILE")
    since = ENV.fetch("SINCE")
    until_date = ENV.fetch("UNTIL")
    report = Mpesa::ReconcileStatement.new.call(path: file, kind: kind, since: since, until_date: until_date)

    puts "kind=#{report.fetch(:kind)}"
    puts "statement_only=#{report.fetch(:statement_only).size}"
    puts "application_only=#{report.fetch(:application_only).size}"
    puts "amount_mismatches=#{report.fetch(:amount_mismatches).size}"
    report.fetch(:statement_only).each { |receipt| puts "statement_only receipt=#{receipt}" }
    report.fetch(:application_only).each { |receipt| puts "application_only receipt=#{receipt}" }
    report.fetch(:amount_mismatches).each do |item|
      puts "amount_mismatch receipt=#{item.fetch(:receipt)} application=#{item.fetch(:application_amount)} statement=#{item.fetch(:statement_amount)}"
    end
  end
end
