# Run from the command line: bundle exec ruby benchmarks/reject_extract.rb
require 'kalibera'
require 'benchmark/ips'
require 'digest'

MESSAGE = <<~MESSAGE
  Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vestibulum pulvinar
  magna metus, vel facilisis sapien mollis sit amet. Pellentesque bibendum mi a
  mi malesuada dignissim. Donec pharetra purus at finibus pretium. Sed vitae
  odio lobortis, bibendum mi id, eleifend mauris. Integer varius molestie
  bibendum.
MESSAGE

Benchmark.ips do |x|
  x.config stats: :bootstrap, confidence: 95

  x.report("MD5") do
    Digest::MD5.hexdigest MESSAGE
  end

  x.report("RMD160") do
    Digest::RMD160.hexdigest MESSAGE
  end

  x.report("SHA1") do
    Digest::SHA1.hexdigest MESSAGE
  end

  x.report("SHA2") do
    Digest::SHA2.hexdigest MESSAGE
  end

  x.compare!
end

__END__

Warming up --------------------------------------
                 MD5    32.125k i/100ms
              RMD160    21.157k i/100ms
                SHA1    30.969k i/100ms
                SHA2    17.655k i/100ms
Calculating -------------------------------------
                 MD5    402.545k (± 0.9%) i/s -      2.024M in   5.035449s
              RMD160    239.013k (± 0.7%) i/s -      1.206M in   5.049813s
                SHA1    402.324k (± 0.8%) i/s -      2.013M in   5.008906s
                SHA2    199.182k (± 0.8%) i/s -      1.006M in   5.058252s
                   with 95.0% confidence

Comparison:
                 MD5:   402545.1 i/s
                SHA1:   402323.6 i/s - same-ish: difference falls within error
              RMD160:   239013.3 i/s - 1.68x  (± 0.02) slower
                SHA2:   199182.2 i/s - 2.02x  (± 0.03) slower
                   with 95.0% confidence
