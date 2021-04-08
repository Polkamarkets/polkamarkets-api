
module BigNumberHelper
  def from_big_number_to_integer(number)
    number / 10**18
  end

  def from_big_number_to_float(number)
    number.to_f / 10**18
  end
end
