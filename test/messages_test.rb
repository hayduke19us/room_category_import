require_relative 'test_helper'

class MessagesTest < Tester
  class Car
    include Messages
  end

  def setup
    super
    @car = Car.new
  end

  def test_it_includes_error_handler_error_messages_and_success_messages
    assert_equal [SuccessMessages, ErrorMessages, ErrorHandler], Messages.included_modules
  end

  def test_say_outputs_and_adds_space_around_messages
    assert_output("\n\ntest\n\n") { @car.say 'test' }
  end

  def test_counter_msg_prints_a_dot
    assert_output('.') { @car.counter_msg }
  end

  def test_failure_msg_prints_a_F_for_failure
    assert_output("F\n\n") { @car.failure_msg }
  end
end
