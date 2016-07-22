require 'minitest/autorun'
require 'minitest/pride'

Dir.glob(File.expand_path('lib/*')).each { |file| require file }

class Tester < Minitest::Test
  def base_path
    File.expand_path('../out.txt', __FILE__)
  end

  def silence_output
    @stdout = $stdout
    $stdout = File.new(base_path, "w")
  end

  def setup
    silence_output
  end

  def teardown
    $stdout = @stdout
    FileUtils.rm base_path
  end
end
