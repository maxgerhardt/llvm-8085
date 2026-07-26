#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Locate the toolchain. A single-config build puts binaries in build*/bin;
# a multi-config (e.g. MSVC/Xcode) build puts them in build*/<Config>/bin.
if [[ -z "${TOOLBIN:-}" ]]; then
  for cand in \
    "$ROOT/llvm-project/build-clang-8085/bin" \
    "$ROOT/llvm-project/build-clang-8085/Release/bin"; do
    if [[ -x "$cand/clang" || -x "$cand/clang.exe" ]]; then
      TOOLBIN="$cand"; break
    fi
  done
  TOOLBIN="${TOOLBIN:-$ROOT/llvm-project/build-clang-8085/bin}"
fi
SYSROOT="${SYSROOT:-$ROOT/sysroot}"

# Parse --undoc flag
UNDOC=0
for arg in "$@"; do
  if [[ "$arg" == "--undoc" ]]; then
    UNDOC=1
  fi
done

CLANG="${TOOLBIN}/clang"
LLC="${TOOLBIN}/llc"
AR="${TOOLBIN}/llvm-ar"

BUILTINS_DIR="${ROOT}/llvm-project/compiler-rt/lib/builtins"
LIBI8085_BUILTINS_DIR="${ROOT}/builtins"
OUT_DIR="${SYSROOT}/lib/builtins"

# Extra flags for undocumented instruction support.
# The undoc feature is enabled by appending "+undoc" to the target triple
# (e.g. -target i8085-unknown-elf+undoc). The old "-Xclang -target-feature
# -Xclang +undoc" form no longer reaches the integrated assembler for .S
# files, so the triple suffix is the supported path. -DUNDOC still selects
# the undoc code paths in the hand-written assembly (see undoc_macros.inc).
ASM_TARGET="i8085-unknown-elf"
ASM_UNDOC_FLAGS=""
if [[ "${UNDOC}" -eq 1 ]]; then
  ASM_TARGET="i8085-unknown-elf+undoc"
  ASM_UNDOC_FLAGS="-DUNDOC"
  echo "Building with undocumented 8085 instruction support"
fi

if [[ ! -x "${CLANG}" || ! -x "${LLC}" || ! -x "${AR}" ]]; then
  echo "missing toolchain in ${TOOLBIN}" >&2
  exit 1
fi

mkdir -p "${OUT_DIR}"
rm -f "${OUT_DIR}"/*.o

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

float_sources_o0=(
  # fixsfsi, fixunssfsi, floatsisf, floatunsisf — now hand-written in softfp.S
)

float_sources_o0_softfp=(
  fixsfdi
  fixunssfdi
)

float_sources_o1=(
)
float_sources_os=(
  # fp_mode — now hand-written in softfp.S (__fe_getround, __fe_raise_inexact)
)

int_sources_o0=(
  # muldi3 -- now provided by hand-written assembly in int_mul.S
)

int_sources_os=(
)

for base in "${float_sources_o0[@]}"; do
  src="${BUILTINS_DIR}/${base}.c"
  if [[ ! -f "${src}" ]]; then
    echo "missing source: ${src}" >&2
    exit 1
  fi
  "${CLANG}" -target i8085-unknown-elf -O0 -ffreestanding -fno-builtin \
    -nostdlib -I "${LIBI8085_BUILTINS_DIR}" -I "${BUILTINS_DIR}" \
    -emit-llvm -c "${src}" -o "${tmpdir}/${base}.bc"
  "${LLC}" -mtriple=i8085-unknown-elf -filetype=obj \
    "${tmpdir}/${base}.bc" -o "${OUT_DIR}/${base}.o"
done

for base in "${float_sources_o0_softfp[@]}"; do
  src="${BUILTINS_DIR}/${base}.c"
  if [[ ! -f "${src}" ]]; then
    echo "missing source: ${src}" >&2
    exit 1
  fi
  "${CLANG}" -target i8085-unknown-elf -O0 -ffreestanding -fno-builtin \
    -D__SOFTFP__ -nostdlib -I "${LIBI8085_BUILTINS_DIR}" -I "${BUILTINS_DIR}" \
    -emit-llvm -c "${src}" -o "${tmpdir}/${base}.bc"
  "${LLC}" -mtriple=i8085-unknown-elf -filetype=obj \
    "${tmpdir}/${base}.bc" -o "${OUT_DIR}/${base}.o"
done

for base in "${float_sources_o1[@]}"; do
  src="${BUILTINS_DIR}/${base}.c"
  if [[ ! -f "${src}" ]]; then
    echo "missing source: ${src}" >&2
    exit 1
  fi
  "${CLANG}" -target i8085-unknown-elf -O0 -ffreestanding -fno-builtin \
    -nostdlib -I "${LIBI8085_BUILTINS_DIR}" -I "${BUILTINS_DIR}" \
    -emit-llvm -c "${src}" -o "${tmpdir}/${base}.bc"
  "${LLC}" -mtriple=i8085-unknown-elf -filetype=obj \
    "${tmpdir}/${base}.bc" -o "${OUT_DIR}/${base}.o"
done

for base in "${float_sources_os[@]}"; do
  src="${BUILTINS_DIR}/${base}.c"
  if [[ ! -f "${src}" ]]; then
    echo "missing source: ${src}" >&2
    exit 1
  fi
  "${CLANG}" -target i8085-unknown-elf -Os -ffreestanding -fno-builtin \
    -nostdlib -I "${LIBI8085_BUILTINS_DIR}" -I "${BUILTINS_DIR}" \
    -emit-llvm -c "${src}" -o "${tmpdir}/${base}.bc"
  "${LLC}" -mtriple=i8085-unknown-elf -filetype=obj \
    "${tmpdir}/${base}.bc" -o "${OUT_DIR}/${base}.o"
done

for base in "${int_sources_o0[@]}"; do
  src="${BUILTINS_DIR}/${base}.c"
  if [[ ! -f "${src}" ]]; then
    echo "missing source: ${src}" >&2
    exit 1
  fi
  "${CLANG}" -target i8085-unknown-elf -O0 -ffreestanding -fno-builtin \
    -nostdlib -I "${BUILTINS_DIR}" \
    -emit-llvm -c "${src}" -o "${tmpdir}/${base}.bc"
  "${LLC}" -mtriple=i8085-unknown-elf -filetype=obj \
    "${tmpdir}/${base}.bc" -o "${OUT_DIR}/${base}.o"
done

for base in "${int_sources_os[@]}"; do
  src="${BUILTINS_DIR}/${base}.c"
  if [[ ! -f "${src}" ]]; then
    echo "missing source: ${src}" >&2
    exit 1
  fi
  "${CLANG}" -target i8085-unknown-elf -Os -ffreestanding -fno-builtin \
    -nostdlib -I "${BUILTINS_DIR}" \
    -emit-llvm -c "${src}" -o "${tmpdir}/${base}.bc"
  "${LLC}" -mtriple=i8085-unknown-elf -filetype=obj \
    "${tmpdir}/${base}.bc" -o "${OUT_DIR}/${base}.o"
done

# Target-specific helpers.
if [[ -f "${LIBI8085_BUILTINS_DIR}/clzsi2.S" ]]; then
  # shellcheck disable=SC2086
  "${CLANG}" -target ${ASM_TARGET} ${ASM_UNDOC_FLAGS} -c "${LIBI8085_BUILTINS_DIR}/clzsi2.S" \
    -o "${OUT_DIR}/clzsi2.o"
else
  echo "missing source: ${LIBI8085_BUILTINS_DIR}/clzsi2.S" >&2
  exit 1
fi

# Note: 64-bit division (int_divdi3) is now hand-written assembly in int_divdi3.S,
# assembled in the hand-written assembly loop below.

# Local soft-float helpers — now hand-written in softfp.S:
# addsf3, subsf3, negsf2, mulsf3, divsf3, comparesf2, fixsfsi, fixunssfsi,
# floatsisf, floatunsisf, fe_getround, fe_raise_inexact

# Hand-written assembly helpers: memory operations, integer multiply,
# integer division, 64-bit shifts, and 64-bit add/sub.
# Assembly avoids bootstrapping issues and gives much better performance
# than the C versions compiled through the i8085 backend.
for helper in memops int_mul int_div int_shift int_shift64 int_arith64 int_divdi3 ctzsi2 ctzdi2 clzdi2 popcountsi2 int_rotate int_rotate64 int_fshl stringops softfp malloc; do
  src="${LIBI8085_BUILTINS_DIR}/${helper}.S"
  if [[ ! -f "${src}" ]]; then
    echo "missing source: ${src}" >&2
    exit 1
  fi
  # shellcheck disable=SC2086
  "${CLANG}" -target ${ASM_TARGET} ${ASM_UNDOC_FLAGS} -c "${src}" -o "${OUT_DIR}/${helper}.o"
done

for helper in floatdisf floatundisf; do
  src="${LIBI8085_BUILTINS_DIR}/${helper}.c"
  if [[ ! -f "${src}" ]]; then
    echo "missing source: ${src}" >&2
    exit 1
  fi
  "${CLANG}" -target i8085-unknown-elf -O0 -ffreestanding -fno-builtin \
    -nostdlib -I "${LIBI8085_BUILTINS_DIR}" -I "${BUILTINS_DIR}" \
    -emit-llvm -c "${src}" -o "${tmpdir}/${helper}.bc"
  "${LLC}" -mtriple=i8085-unknown-elf -filetype=obj \
    "${tmpdir}/${helper}.bc" -o "${OUT_DIR}/${helper}.o"
done

if [[ "${UNDOC}" -eq 1 ]]; then
  LIBGCC_OUT="${SYSROOT}/lib/libgcc-undoc.a"
else
  LIBGCC_OUT="${SYSROOT}/lib/libgcc.a"
fi

rm -f "${LIBGCC_OUT}"
"${AR}" rcs "${LIBGCC_OUT}" "${OUT_DIR}"/*.o

echo "libgcc rebuilt into ${LIBGCC_OUT}"
