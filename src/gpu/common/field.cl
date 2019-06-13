// FinalityLabs - 2019
// Arbitrary size prime-field arithmetic library (add, sub, mul, pow)
// Montgomery reduction parameters:
// B = 2^32 (Because our digits are uint32)

typedef struct { limb val[FIELD_LIMBS]; } FIELD;

void print(FIELD v) {
  printf("%u %u %u %u %u %u %u %u %u %u %u %u\n",
    v.val[11],v.val[10],v.val[9],v.val[8],v.val[7],v.val[6],v.val[5],v.val[4],v.val[3],v.val[2],v.val[1],v.val[0]);
}

// Greater than or equal
bool FIELD_gte(FIELD a, FIELD b) {
  for(int i = FIELD_LIMBS - 1; i >= 0; i--){
    if(a.val[i] > b.val[i])
      return true;
    if(a.val[i] < b.val[i])
      return false;
  }
  return true;
}

// Equals
bool FIELD_eq(FIELD a, FIELD b) {
  for(int i = 0; i < FIELD_LIMBS; i++)
    if(a.val[i] != b.val[i])
      return false;
  return true;
}

// Normal addition
FIELD FIELD_add_(FIELD a, FIELD b) {
  uint32 carry = 0;
  for(int i = 0; i < FIELD_LIMBS; i++) {
    limb old = a.val[i];
    a.val[i] += b.val[i] + carry;
    carry = carry ? old >= a.val[i] : old > a.val[i];
  }
  return a;
}

// Normal subtraction
FIELD FIELD_sub_(FIELD a, FIELD b) {
  uint32 borrow = 0;
  for(int i = 0; i < FIELD_LIMBS; i++) {
    limb old = a.val[i];
    a.val[i] -= b.val[i] + borrow;
    borrow = borrow ? old <= a.val[i] : old < a.val[i];
  }
  return a;
}

uint64 hi(uint64 x) {
    return x >> 32;
}

uint64 lo(uint64 x) {
    return ((1L << 32) - 1) & x;
}

// Modular multiplication
FIELD FIELD_mul(FIELD a, FIELD b) {
  FIELD p = FIELD_P; // TODO: Find a solution for this

  // Long multiplication
  limb res[FIELD_LIMBS * 2] = {0};
  for(uint32 i = 0; i < FIELD_LIMBS; i++) {
    limb carry = 0;
    for(uint32 j = 0; j < FIELD_LIMBS; j++) {
      res[i + j] = mac_with_carry(a.val[i], b.val[j], res[i + j], &carry);
    }
    res[i + FIELD_LIMBS] = carry;
  }

  // Montgomery reduction
  for(uint32 i = 0; i < FIELD_LIMBS; i++) {
    limb u = FIELD_INV * res[i];
    limb carry = 0;
    for(uint32 j = 0; j < FIELD_LIMBS; j++)
      res[i + j] = mac_with_carry(u, p.val[j], res[i + j], &carry);
    add_digit(res + i + FIELD_LIMBS, carry);
  }

  // Divide by R
  FIELD result;
  for(int i = 0; i < FIELD_LIMBS; i++) result.val[i] = res[i+FIELD_LIMBS];

  if(FIELD_gte(result, p))
    result = FIELD_sub_(result, p);

  return result;
}

// Modular negation
FIELD FIELD_neg(FIELD a) {
  FIELD p = FIELD_P; // TODO: Find a solution for this
  return FIELD_sub_(p, a);
}

// Modular subtraction
FIELD FIELD_sub(FIELD a, FIELD b) {
  FIELD p = FIELD_P; // TODO: Find a solution for this
  FIELD res = FIELD_sub_(a, b);
  if(!FIELD_gte(a, b)) res = FIELD_add_(res, p);
  return res;
}

// Modular addition
FIELD FIELD_add(FIELD a, FIELD b) {
  return FIELD_sub(a, FIELD_neg(b));
}

// Modular exponentiation
FIELD FIELD_pow(FIELD base, uint32 exponent) {
  FIELD res = FIELD_ONE;
  while(exponent > 0) {
    if (exponent & 1)
      res = FIELD_mul(res, base);
    exponent = exponent >> 1;
    base = FIELD_mul(base, base);
  }
  return res;
}

FIELD FIELD_pow_cached(__global FIELD *bases, uint32 exponent) {
  FIELD res = FIELD_ONE;
  uint32 i = 0;
  while(exponent > 0) {
    if (exponent & 1)
      res = FIELD_mul(res, bases[i]);
    exponent = exponent >> 1;
    i++;
  }
  return res;
}
