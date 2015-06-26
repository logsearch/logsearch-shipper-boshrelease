# encoding: utf-8

require 'spec_helper'
require 'json'

Dir.glob("#{ENV['RELEASE_DIR']}/jobs/**/logsearch/logs/*/expected.testdata").each do | path |
  describe File.dirname(path) do
    config 'filter {' + File.read("#{File.dirname(path)}/logstash-filters.conf") + '}'

    ("\n" + File.read(path)).split(/\r?\n===[^\n]*\r?\n/).each do | test |
      next if "" == test.strip

      split = test.split(/\r?\n---\r?\n/, 2)
      expected = JSON.parse(split[1])
    
      sample('@message' => split[0]) do
        subject.remove "@version"
        subject.remove "tags" if [] === subject['tags']

        expected.each do | k, v |
          if "@timestamp" == k
            if v.nil?
              # assume the event is known to not have a parseable timestamp
              insist { subject[k] }.is_a? LogStash::Timestamp
            else
              insist { subject[k] } === Time.iso8601(v)
            end
          else
            insist { subject[k] } === v
          end
        end
      
        insist { subject.to_hash.keys.sort } === expected.keys.sort
      end
    end
  end
end
