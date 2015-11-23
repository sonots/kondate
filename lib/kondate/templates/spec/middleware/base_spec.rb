require 'spec_helper'

describe file('/tmp') do
  it { should be_directory }
end
