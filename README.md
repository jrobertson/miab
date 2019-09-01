# Introducing the Miab gem

## Usage

    require 'miab'

    puts Miab.new("temperature", domain: 'home', user: 'james', 
          target: %w(pero primo tito olga fortina ottavia aldo sol), 
          password: 'secret').cast

The above example uses the Miab gem to log into each Raspberry Pi with the username *james* and with the same password for each host. It then queries the CPU temperature for each Pi.

## Output

<pre>
{"pero.home"=&gt;{:temperature=&gt;"44008"},
 "primo.home"=&gt;{:temperature=&gt;"45084"},
 "tito.home"=&gt;{:temperature=&gt;"48312"},
 "olga.home"=&gt;{:temperature=&gt;"47616"},
 "fortina.home"=&gt;{:temperature=&gt;"49230"},
 "ottavia.home"=&gt;{:temperature=&gt;"42236"},
 "aldo.home"=&gt;{:temperature=&gt;"44388"},
 "sol.home"=&gt;{:temperature=&gt;"41698"}}
</pre>

## Resources

* miab https://rubygems.org/gems/miab

miab ssh gem netssh rpi temperature
