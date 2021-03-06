//
//  sigma.cu
//
//  These sigma values _roughly_ correspond to those used by Gourdon, but have
//  been adapted so that the sum can be partitioned in a similar manner to that
//  found in Kim Walisch's primecount.
//
//

#include <stdint.h>
#include <CUDASieve/cudasieve.hpp>
#include <uint128_t.cuh>
#include <thrust/binary_search.h>
#include <thrust/execution_policy.h>
#include <math.h>
#include <math_functions.h>

#include "cudapix.hpp"
#include "general/device_functions.cuh"
#include "Deleglise-Rivat/deleglise-rivat.hpp"

uint16_t threadsPerBlock = 256;

int64_t deleglise_rivat64::sigma1() const
{
  int64_t s1 = (pi_y - pi_sqrtx) * (pi_y - pi_sqrtx - 1) / 2;

  return s1;
}

int64_t deleglise_rivat64::sigma2() const
{
  int64_t s2 = pi_qrtx * (pi_qrtx - 3) / 2;
  s2 -= pi_sqrtz * (pi_sqrtz - 3) / 2;
  s2 *= pi_y;

  return s2;
}

int64_t deleglise_rivat64::sigma3() const
{
  int64_t s3 = pi_cbrtx;
  s3 *= (s3 - 1) * (2 * s3 - 1) / 6;
  s3 -= pi_cbrtx;
  s3 -= pi_qrtx * (pi_qrtx - 1) * (2 * pi_qrtx - 1) / 6;
  s3 += pi_qrtx;

  return s3;
}

int64_t deleglise_rivat64::sigma4() const
{
  int64_t s4 = 0;
  PrimeArray p(qrtx, sqrtz);
  PrimeArray pi(sqrtz, x / (y * qrtx));

  p.d_primes = CudaSieve::getDevicePrimes(p.bottom, p.top, p.len, 0);
  pi.d_primes = CudaSieve::getDevicePrimes(pi.bottom, pi.top, pi.len, 0);

  xOverPY(p.d_primes, x, y, p.len);
  cudaDeviceSynchronize();

  thrust::upper_bound(thrust::device, pi.d_primes, pi.d_primes + pi.len, p.d_primes, p.d_primes + p.len, p.d_primes);

  s4 = thrust::reduce(thrust::device, p.d_primes, p.d_primes + p.len);

  s4 *= pi_y;

  return s4;
}

int64_t deleglise_rivat64::sigma5() const
{
  int64_t s5 = 0;
  PrimeArray p(sqrtz, cbrtx);
  PrimeArray pi(cbrtx, y);

  p.d_primes = CudaSieve::getDevicePrimes(p.bottom, p.top, p.len, 0);
  pi.d_primes = CudaSieve::getDevicePrimes(pi.bottom, pi.top, pi.len, 0);

  xOverPSquared(p.d_primes, x, p.len);
  cudaDeviceSynchronize();

  thrust::upper_bound(thrust::device, pi.d_primes, pi.d_primes + pi.len, p.d_primes, p.d_primes + p.len, p.d_primes);

  s5 = thrust::reduce(thrust::device, p.d_primes, p.d_primes + p.len);

  return s5;
}

int64_t deleglise_rivat64::sigma6() const
{
  int64_t s6 = 0;
  PrimeArray p(qrtx, cbrtx);
  PrimeArray pi(cbrtx, qrtx * sqrt(qrtx));

  p.d_primes = CudaSieve::getDevicePrimes(p.bottom, p.top, p.len, 0);
  pi.d_primes = CudaSieve::getDevicePrimes(pi.bottom, pi.top, pi.len, 0);

  sqrtxOverSqrtp(p.d_primes, sqrtx, p.len);
  cudaDeviceSynchronize();

  thrust::upper_bound(thrust::device, pi.d_primes, pi.d_primes + pi.len, p.d_primes, p.d_primes + p.len, p.d_primes);

  squareEach(p.d_primes, p.len);
  cudaDeviceSynchronize();

  s6 = thrust::reduce(thrust::device, p.d_primes, p.d_primes + p.len);

  return -s6;
}


///
/// The __global__ functions used below are defined in general/device_functions.cu
///


///  For sigma4:
///  array[i] = x / (array[i] * y);
///  which represents the equation n = x (p_i * y)
///
inline void xOverPY(uint64_t * p, uint128_t x, uint64_t y, size_t len)
{
  global::xOverPY<<<len/threadsPerBlock + 1, threadsPerBlock>>>(p, x, y, len);
}

inline void xOverPY(uint64_t * p, uint64_t x, uint64_t y, size_t len)
{
  global::xOverPY<<<len/threadsPerBlock + 1, threadsPerBlock>>>(p, x, y, len);
}


///  For sigma5:
///  array[i] = x / (array[i] * array[i]);
///  which represents the equation n = x / (p_i * p_i)
///
inline void xOverPSquared(uint64_t * p, uint128_t x, size_t len)
{
  global::xOverPSquared<<<len/threadsPerBlock + 1, threadsPerBlock>>>(p, x, len);
}

inline void xOverPSquared(uint64_t * p, uint64_t x, size_t len)
{
  global::xOverPSquared<<<len/threadsPerBlock + 1, threadsPerBlock>>>(p, x, len);
}


///  For sigma6:
///  array[i] = sqrt(x) / sqrt(p);
///  which represents the equation n = x^(1/2) / p_i^(1/2)
///  note that sqrt(x) is precomputed, so don't call this function x.
///

inline void sqrtxOverSqrtp(uint64_t * p, uint64_t sqrtx, size_t len)
{
  global::sqrtxOverSqrtp<<<len/threadsPerBlock + 1, threadsPerBlock>>>(p, sqrtx, len);
}


///  For sigma6:
///  array[i] = array[i]^2;
///  which represents the expression pi(n)^2

inline void squareEach(uint64_t * pi, size_t len)
{
  global::squareEach<<<len/threadsPerBlock + 1, threadsPerBlock>>>(pi, len);
}
