
module BigNumberHelper
  def from_big_number_to_integer(number, decimals = 18)
    number / 10**decimals
  end

  def from_big_number_to_float(number, decimals = 18)
    number.to_f / 10**decimals
  end

  def from_integer_to_big_number(number, decimals = 18)
    number * 10**decimals
  end

  def from_float_to_big_number(number, decimals = 18)
    (number * 10**decimals).to_i
  end
end
