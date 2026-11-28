///|
/// A double-precision complex number.
#derive(Eq, Debug)
pub(all) struct Complex {
  real : Double
  imag : Double
}

///|
pub fn Complex::new(real : Double, imag : Double) -> Complex {
  Complex::{ real, imag, }
}

///|
pub impl Add for Complex with fn add(self, other) -> Complex {
  Complex::new(self.real + other.real, self.imag + other.imag)
}

///|
pub impl Sub for Complex with fn sub(self, other) -> Complex {
  Complex::new(self.real - other.real, self.imag - other.imag)
}

///|
pub impl Neg for Complex with fn neg(self) -> Complex {
  Complex::new(-self.real, -self.imag)
}

///|
pub impl Mul for Complex with fn mul(self, other) -> Complex {
  Complex::new(
    self.real * other.real - self.imag * other.imag,
    self.real * other.imag + self.imag * other.real,
  )
}

///|
pub impl Div for Complex with fn div(self, other) -> Complex {
  let denominator = other.real * other.real + other.imag * other.imag
  let inverse = @luna_generic.Inverse::inv(denominator)
  Complex::new(
    (self.real * other.real + self.imag * other.imag) * inverse,
    (self.imag * other.real - self.real * other.imag) * inverse,
  )
}

///|
pub impl @luna_generic.Inverse for Complex with fn inv(self) -> Complex {
  let denominator = self.real * self.real + self.imag * self.imag
  let inverse = @luna_generic.Inverse::inv(denominator)
  Complex::new(self.real * inverse, -self.imag * inverse)
}

///|
pub impl @luna_generic.Zero for Complex with fn zero() -> Complex {
  Complex::new(0.0, 0.0)
}

///|
pub impl @luna_generic.One for Complex with fn one() -> Complex {
  Complex::new(1.0, 0.0)
}

///|
pub impl @luna_generic.AddMonoid for Complex

///|
pub impl @luna_generic.AddGroup for Complex

///|
pub impl @luna_generic.MulMonoid for Complex

///|
pub impl @luna_generic.Semiring for Complex

///|
pub impl @luna_generic.Ring for Complex

///|
pub impl @luna_generic.Field for Complex
