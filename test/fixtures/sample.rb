# frozen_string_literal: true

# Sample class for E2E testing
class Calculator
  # Adds two numbers together
  # @param a [Integer] first number
  # @param b [Integer] second number
  # @return [Integer] the sum
  def add(a, b)
    a + b
  end

  # Multiplies two numbers
  # @param a [Integer] first number
  # @param b [Integer] second number
  # @return [Integer] the product
  def multiply(a, b)
    a * b
  end
end

calc = Calculator.new
result = calc.add(1, 2)
puts result
