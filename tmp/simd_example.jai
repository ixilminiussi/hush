#import "Basic";
#import "Math";
#import "SIMD";

// ============================================================================
//  SIMD TUTORIAL FOR JAI
// ============================================================================
//
//  WHAT IS SIMD?
//  -------------
//  SIMD = Single Instruction, Multiple Data.
//  Instead of operating on one float at a time, you operate on 4 (or 8, or 16)
//  floats with a single CPU instruction.
//
//  Think of it like this:
//    Scalar:  a + b  =  one addition
//    SIMD:    [a0,a1,a2,a3] + [b0,b1,b2,b3]  =  one instruction, four additions
//
//  Your CPU has special wide registers (128-bit SSE, 256-bit AVX) that hold
//  multiple values packed together. SIMD instructions operate on all lanes
//  simultaneously.
//
//  JAI'S SIMD MODULE
//  -----------------
//  Jai provides SIMD_Array(count, type) - a fixed-size array that represents
//  a SIMD register. The module overloads +, -, *, / so you can write natural
//  arithmetic. Currently these are scalar loops that LLVM *may* auto-vectorize,
//  but the API is designed so that when native backends arrive, the same code
//  will map to real SIMD instructions.
//
//  KEY CONCEPT: "LANES"
//  --------------------
//  A SIMD_Array(4, float32) has 4 "lanes". Each lane holds one float.
//  When you do a + b, each lane is added independently:
//    lane 0: a[0] + b[0]
//    lane 1: a[1] + b[1]
//    lane 2: a[2] + b[2]
//    lane 3: a[3] + b[3]
//
//  There is NO cross-lane interaction in basic ops. That's what makes SIMD fast:
//  the lanes are independent and can execute in parallel.
// ============================================================================

// A convenient alias. 4 floats = 128 bits = one SSE register.
float4 :: SIMD_Array(4, float32);

// ============================================================================
//  LESSON 1: Basic lane-wise operations
// ============================================================================

lesson_1_basics :: () {
    print("\n========== LESSON 1: Lane-wise Operations ==========\n\n");

    // Creating SIMD values. Each element is a "lane".
    a: float4 = ---;
    a.data = .[1.0, 2.0, 3.0, 4.0];

    b: float4 = ---;
    b.data = .[10.0, 20.0, 30.0, 40.0];

    // Every operation happens PER LANE, independently:
    print("a           = %\n", a.data);
    print("b           = %\n", b.data);
    print("a + b       = %\n", (a + b).data);   // [11, 22, 33, 44]
    print("a * b       = %\n", (a * b).data);   // [10, 40, 90, 160]
    print("a * 3.0     = %\n", (a * 3.0).data); // scalar broadcast: [3, 6, 9, 12]

    // KEY INSIGHT: there is no single "add" instruction happening here.
    // There are 4 adds happening simultaneously. That's the whole point.
    // On real SIMD hardware, a + b is ONE instruction that does 4 adds.
}

// ============================================================================
//  LESSON 2: Horizontal operations (cross-lane)
// ============================================================================
//
//  Most SIMD ops are vertical (lane-by-lane). But sometimes you need to
//  combine values ACROSS lanes. This is called a "horizontal" operation,
//  and it's typically SLOWER than vertical ops because SIMD hardware is
//  optimized for vertical parallelism.
//
//  Rule of thumb: minimize horizontal ops. Do as much vertical work as
//  possible, then reduce at the very end.
// ============================================================================

lesson_2_horizontal :: () {
    print("\n========== LESSON 2: Horizontal Operations ==========\n\n");

    a: float4 = ---;
    a.data = .[1.0, 2.0, 3.0, 4.0];

    // horizontal_sum: adds ALL lanes together -> single scalar
    sum := horizontal_sum(a);
    print("a                  = %\n", a.data);
    print("horizontal_sum(a)  = %  (1+2+3+4 = 10)\n", sum);

    // This is the pattern for dot products:
    //   1. Multiply lane-wise (vertical, fast)
    //   2. Sum the result   (horizontal, slow but only once)
    b: float4 = ---;
    b.data = .[2.0, 3.0, 4.0, 5.0];

    products := a * b;  // [2, 6, 12, 20]  -- fast, one instruction
    dot := horizontal_sum(products);  // 2+6+12+20 = 40  -- slow, but only once
    print("\na                  = %\n", a.data);
    print("b                  = %\n", b.data);
    print("a * b (per-lane)   = %\n", products.data);
    print("dot(a, b)          = %  (horizontal sum of products)\n", dot);
}

// ============================================================================
//  LESSON 3: Comparisons and masks
// ============================================================================
//
//  SIMD comparisons don't return a single bool. They return a SIMD_Array
//  where each lane is 0 (false) or nonzero (true). You can extract this
//  as a bitmask to make branching decisions.
//
//  This is how SIMD handles conditionals: instead of if/else per element,
//  you compute BOTH branches and use the mask to select results.
//  (This is called "predication" or "masking".)
// ============================================================================

lesson_3_masks :: () {
    print("\n========== LESSON 3: Comparisons & Masks ==========\n\n");

    values: float4 = ---;
    values.data = .[1.0, 5.0, 3.0, 7.0];

    // Compare each lane against a scalar threshold
    threshold :: 4.0;
    mask := values > threshold;

    print("values          = %\n", values.data);
    print("values > %    = %\n", threshold, mask.data);
    print("  (0 = false, nonzero = true)\n");

    // get_mask extracts one bit per lane into an integer
    bits := get_mask(mask);
    print("get_mask        = %  (binary: lanes 1 and 3 are > 4.0)\n", bits);

    // WHY MASKS MATTER:
    // In scalar code you'd write:  if x > 4 then result = a else result = b;
    // In SIMD you can't branch per lane. Instead you compute both and blend:
    //   result = (a & mask) | (b & ~mask)
    // Jai's SIMD module doesn't have blend yet, but that's the mental model.
}

// ============================================================================
//  LESSON 4: Processing arrays in SIMD chunks
// ============================================================================
//
//  The real power of SIMD: processing large arrays 4 elements at a time.
//  The pattern is always:
//    1. Loop in steps of 4 (your SIMD width)
//    2. Load 4 elements into a SIMD register
//    3. Do your math (all vertical ops, very fast)
//    4. Store results back (or accumulate into an accumulator)
//    5. At the end, do one horizontal reduction if needed
// ============================================================================

ARRAY_SIZE :: 1024;

scalar_dot_product :: (a: [] float32, b: [] float32) -> float32 {
    sum: float32 = 0;
    for 0..a.count-1 {
        sum += a[it] * b[it];  // one multiply, one add, per iteration
    }
    return sum;
}

simd_dot_product :: (a: [] float32, b: [] float32) -> float32 {
    assert(a.count % 4 == 0);

    // Accumulator: 4 partial sums running in parallel
    acc: float4;  // zero-initialized

    chunks := a.count / 4;
    for 0..chunks-1 {
        i := it * 4;

        // Load 4 elements from each array
        va: float4 = ---;
        vb: float4 = ---;
        va.data[0] = a[i];   va.data[1] = a[i+1]; va.data[2] = a[i+2]; va.data[3] = a[i+3];
        vb.data[0] = b[i];   vb.data[1] = b[i+1]; vb.data[2] = b[i+2]; vb.data[3] = b[i+3];

        // Multiply 4 pairs at once, accumulate 4 partial sums
        acc = acc + (va * vb);
        // acc[0] accumulates a[0]*b[0] + a[4]*b[4] + a[8]*b[8] + ...
        // acc[1] accumulates a[1]*b[1] + a[5]*b[5] + a[9]*b[9] + ...
        // acc[2] accumulates a[2]*b[2] + a[6]*b[6] + a[10]*b[10] + ...
        // acc[3] accumulates a[3]*b[3] + a[7]*b[7] + a[11]*b[11] + ...
    }

    // ONE horizontal sum at the very end (not inside the loop!)
    return horizontal_sum(acc);
}

lesson_4_arrays :: () {
    print("\n========== LESSON 4: Processing Arrays ==========\n\n");

    a: [ARRAY_SIZE] float32;
    b: [ARRAY_SIZE] float32;
    for 0..ARRAY_SIZE-1 {
        a[it] = cast(float32)(it % 17) * 0.1;
        b[it] = cast(float32)(it % 13) * 0.2;
    }

    ITERATIONS :: 100_000;

    // Benchmark scalar
    scalar_result: float32;
    t0 := current_time_monotonic();
    for 1..ITERATIONS  scalar_result = scalar_dot_product(a, b);
    t1 := current_time_monotonic();
    scalar_us := to_microseconds(t1 - t0);

    // Benchmark SIMD
    simd_result: float32;
    t2 := current_time_monotonic();
    for 1..ITERATIONS  simd_result = simd_dot_product(a, b);
    t3 := current_time_monotonic();
    simd_us := to_microseconds(t3 - t2);

    print("Array size: % floats, % iterations\n", ARRAY_SIZE, ITERATIONS);
    print("Scalar: %  (% us)\n", scalar_result, scalar_us);
    print("SIMD:   %  (% us)\n", simd_result, simd_us);
    if simd_us > 0
        print("Speedup: %x\n", formatFloat(cast(float64) scalar_us / cast(float64) simd_us, trailing_width=2));

    print("\nNOTE: Since Jai's SIMD module is currently a prototype (scalar loops\n");
    print("that LLVM may auto-vectorize), you might not see a big speedup yet.\n");
    print("The point is: this code structure IS the SIMD pattern. When Jai's\n");
    print("backends emit real SIMD instructions, this code gets faster for free.\n");
}

// ============================================================================
//  LESSON 5: SIMD Matrix4 multiply
// ============================================================================
//
//  Matrix multiply is the classic SIMD showcase. Here's why:
//
//  A Matrix4 row times a Matrix4 column is a dot product of 4 floats.
//  A Matrix4 has 4 rows. So matrix * vector = 4 dot products.
//  Matrix * matrix = 16 dot products.
//
//  But there's a smarter way. Instead of dot products (which need horizontal
//  sums), we can use the "linear combination" approach:
//
//  For result row i:
//    result[i] = m[i][0] * n.row0 + m[i][1] * n.row1 + m[i][2] * n.row2 + m[i][3] * n.row3
//
//  Each n.row is a float4 (4 floats = one SIMD register).
//  m[i][0] is a scalar broadcast to all 4 lanes.
//  So each result row is 4 SIMD multiplies + 3 SIMD adds. No horizontal ops!
//
//  This is called "broadcast-multiply-add" and it's the standard way to do
//  matrix multiply with SIMD.
// ============================================================================

simd_multiply :: (m: Matrix4, n: Matrix4) -> Matrix4 {
    result: Matrix4 = ---;

    // Load n's rows as SIMD registers
    // n.v[0] is the first row (4 floats), etc.
    n_row0: float4 = ---;  n_row0.data = n.v[0].component;
    n_row1: float4 = ---;  n_row1.data = n.v[1].component;
    n_row2: float4 = ---;  n_row2.data = n.v[2].component;
    n_row3: float4 = ---;  n_row3.data = n.v[3].component;

    for row: 0..3 {
        // Broadcast each element of m's row to all 4 lanes
        // m.coef[row][0] * [n00, n01, n02, n03]  -- scalar * vector, all lanes
        // m.coef[row][1] * [n10, n11, n12, n13]
        // m.coef[row][2] * [n20, n21, n22, n23]
        // m.coef[row][3] * [n30, n31, n32, n33]
        r :=  n_row0 * m.coef[row][0]   // 4 multiplies (1 instruction on real SIMD)
            + n_row1 * m.coef[row][1]    // 4 multiplies + 4 adds
            + n_row2 * m.coef[row][2]    // 4 multiplies + 4 adds
            + n_row3 * m.coef[row][3];   // 4 multiplies + 4 adds

        // Total per row: 4 mul + 3 add instructions (instead of 16 mul + 12 add scalar)
        // And ZERO horizontal operations!

        result.v[row].component = r.data;
    }

    return result;
}

lesson_5_matrix :: () {
    print("\n========== LESSON 5: SIMD Matrix4 Multiply ==========\n\n");

    // Set up two test matrices
    m := Matrix4_Identity;
    m._11 = 1; m._12 = 2; m._13 = 3; m._14 = 4;
    m._21 = 5; m._22 = 6; m._23 = 7; m._24 = 8;
    m._31 = 9; m._32 = 10; m._33 = 11; m._34 = 12;
    m._41 = 13; m._42 = 14; m._43 = 15; m._44 = 16;

    n := Matrix4_Identity;
    n._11 = 16; n._12 = 15; n._13 = 14; n._14 = 13;
    n._21 = 12; n._22 = 11; n._23 = 10; n._24 = 9;
    n._31 = 8;  n._32 = 7;  n._33 = 6;  n._34 = 5;
    n._41 = 4;  n._42 = 3;  n._43 = 2;  n._44 = 1;

    // Correctness check
    std_result  := multiply(m, n);
    simd_result := simd_multiply(m, n);

    print("Standard Math.multiply:\n");
    print_matrix(std_result);
    print("\nSIMD multiply:\n");
    print_matrix(simd_result);

    // Verify they match
    match := true;
    for i: 0..15 {
        if abs(std_result.floats[i] - simd_result.floats[i]) > 0.001 {
            match = false;
            break;
        }
    }
    print("\nResults match: %\n", match);

    // Benchmark
    ITERATIONS :: 1_000_000;

    t0 := current_time_monotonic();
    r1 := m;
    for 1..ITERATIONS  r1 = multiply(r1, n);
    t1 := current_time_monotonic();
    std_us := to_microseconds(t1 - t0);

    t2 := current_time_monotonic();
    r2 := m;
    for 1..ITERATIONS  r2 = simd_multiply(r2, n);
    t3 := current_time_monotonic();
    simd_us := to_microseconds(t3 - t2);

    print("\n% iterations of Matrix4 * Matrix4:\n", ITERATIONS);
    print("Standard: % us\n", std_us);
    print("SIMD:     % us\n", simd_us);
    if simd_us > 0
        print("Speedup:  %x\n", formatFloat(cast(float64) std_us / cast(float64) simd_us, trailing_width=2));
}

print_matrix :: (m: Matrix4) {
    for row: 0..3 {
        print("  [");
        for col: 0..3 {
            print("% ", formatFloat(m.coef[row][col], width=8, trailing_width=1));
        }
        print("]\n");
    }
}

// ============================================================================
//  SUMMARY
// ============================================================================
//
//  SIMD RULES OF THUMB:
//
//  1. VERTICAL IS FREE, HORIZONTAL IS EXPENSIVE
//     Lane-wise ops (+, -, *, /) are what SIMD is built for.
//     Cross-lane ops (horizontal_sum, shuffles) are slow. Minimize them.
//
//  2. PROCESS IN CHUNKS
//     Loop over data in steps of your SIMD width (4 for float32 SSE).
//     Load -> compute -> store, repeat.
//
//  3. ACCUMULATE VERTICALLY, REDUCE ONCE
//     Don't horizontal_sum inside a loop. Keep 4 partial sums in a float4,
//     then horizontal_sum once at the end.
//
//  4. BROADCAST-MULTIPLY-ADD FOR MATRICES
//     Instead of dot products (which need horizontal sums), broadcast each
//     scalar across all lanes and multiply with full rows.
//     This keeps everything vertical.
//
//  5. ALIGNMENT MATTERS (on real hardware)
//     SIMD loads are fastest when data is 16-byte aligned (SSE) or
//     32-byte aligned (AVX). Jai's allocators generally handle this.
//
//  6. BRANCH-FREE WITH MASKS
//     SIMD can't branch per lane. Use comparison masks to select between
//     results instead of if/else.
//
// ============================================================================

// ============================================================================
//  LESSON 6: One matrix * many matrices (AoS vs SoA)
// ============================================================================
//
//  Say you have a view-projection matrix V, and 1000 model matrices M[i].
//  You want:  result[i] = V * M[i]   for all i.
//
//  APPROACH 1: "Array of Structures" (AoS) - the obvious way
//  ----------------------------------------------------------
//  Just loop and call simd_multiply for each one.
//  Each call uses SIMD to speed up ONE matrix multiply (4 lanes = 4 floats
//  of one row). This is what lesson 5 does.
//
//  APPROACH 2: "Structure of Arrays" (SoA) - the SIMD way
//  -------------------------------------------------------
//  Instead of storing matrices as [M0, M1, M2, M3, ...] where each M is
//  16 floats, we TRANSPOSE THE STORAGE:
//
//    AoS: M0._11, M0._12, M0._13, M0._14, M0._21, ... M1._11, M1._12, ...
//    SoA: M0._11, M1._11, M2._11, M3._11, M0._12, M1._12, M2._12, M3._12, ...
//
//  Now each float4 holds the SAME element from 4 DIFFERENT matrices.
//  When we do one SIMD multiply, we're computing that element's contribution
//  for 4 matrices simultaneously!
//
//  AoS: 4 lanes = 4 floats of 1 matrix   (SIMD within one multiply)
//  SoA: 4 lanes = 1 float of 4 matrices  (SIMD across multiplies)
//
//  SoA is almost always faster for batch operations. It's the #1 SIMD
//  optimization pattern in game engines, physics, particle systems, etc.
//
// ============================================================================

// SoA layout: each field holds the same element from 4 different matrices
Matrix4_SoA :: struct {
    // e[row][col] is a float4 where each lane is that element from a different matrix
    e: [4][4] float4;
}

// Convert 4 AoS matrices into one SoA bundle
to_soa :: (m0: Matrix4, m1: Matrix4, m2: Matrix4, m3: Matrix4) -> Matrix4_SoA {
    result: Matrix4_SoA = ---;
    for row: 0..3 {
        for col: 0..3 {
            result.e[row][col].data[0] = m0.coef[row][col];
            result.e[row][col].data[1] = m1.coef[row][col];
            result.e[row][col].data[2] = m2.coef[row][col];
            result.e[row][col].data[3] = m3.coef[row][col];
        }
    }
    return result;
}

// Extract one matrix back from a SoA bundle (by lane index)
from_soa :: (s: Matrix4_SoA, lane: int) -> Matrix4 {
    result: Matrix4 = ---;
    for row: 0..3 {
        for col: 0..3 {
            result.coef[row][col] = s.e[row][col].data[lane];
        }
    }
    return result;
}

// Multiply ONE matrix (V) by FOUR matrices simultaneously (SoA)
// This is the same broadcast-multiply-add from lesson 5, but now
// each float4 lane is a different matrix instead of a different column!
simd_multiply_soa :: (v: Matrix4, ms: Matrix4_SoA) -> Matrix4_SoA {
    result: Matrix4_SoA = ---;

    for row: 0..3 {
        for col: 0..3 {
            // result[row][col] = sum over k of: v[row][k] * ms[k][col]
            //
            // v[row][k] is a scalar (same for all 4 matrices) -> broadcast
            // ms[k][col] is a float4 (one per matrix) -> lane-wise multiply
            //
            // This single line computes element [row][col] for ALL 4 matrices!
            result.e[row][col] =  ms.e[0][col] * v.coef[row][0]
                                + ms.e[1][col] * v.coef[row][1]
                                + ms.e[2][col] * v.coef[row][2]
                                + ms.e[3][col] * v.coef[row][3];
        }
    }

    return result;
}

NUM_MATRICES :: 1024;  // must be multiple of 4 for SoA

lesson_6_batch :: () {
    print("\n========== LESSON 6: Batch Multiply (AoS vs SoA) ==========\n\n");

    // The "view-projection" matrix we multiply everything by
    v: Matrix4;
    v._11 = 1.5; v._12 = 0.2; v._13 = 0.0; v._14 = 0.0;
    v._21 = 0.0; v._22 = 1.8; v._23 = 0.1; v._24 = 0.0;
    v._31 = 0.3; v._32 = 0.0; v._33 = 2.0; v._34 = 0.0;
    v._41 = 10;  v._42 = 20;  v._43 = 30;  v._44 = 1.0;

    // Generate model matrices
    models: [NUM_MATRICES] Matrix4;
    for i: 0..NUM_MATRICES-1 {
        f := cast(float)(i + 1);
        models[i] = Matrix4_Identity;
        models[i]._41 = f * 0.1;  // translation x
        models[i]._42 = f * 0.2;  // translation y
        models[i]._43 = f * 0.3;  // translation z
        models[i]._11 = 1.0 + f * 0.001;  // slight scale
    }

    ITERATIONS :: 100_000;

    // --- AoS: loop and multiply one at a time ---
    aos_results: [NUM_MATRICES] Matrix4;
    t0 := current_time_monotonic();
    for 1..ITERATIONS {
        for i: 0..NUM_MATRICES-1 {
            aos_results[i] = simd_multiply(v, models[i]);
        }
    }
    t1 := current_time_monotonic();
    aos_us := to_microseconds(t1 - t0);

    // --- SoA: process 4 matrices per call ---
    soa_bundles: [NUM_MATRICES / 4] Matrix4_SoA;
    soa_results: [NUM_MATRICES / 4] Matrix4_SoA;

    // Convert to SoA (one-time cost, not benchmarked)
    for i: 0..(NUM_MATRICES / 4)-1 {
        j := i * 4;
        soa_bundles[i] = to_soa(models[j], models[j+1], models[j+2], models[j+3]);
    }

    t2 := current_time_monotonic();
    for 1..ITERATIONS {
        for i: 0..(NUM_MATRICES / 4)-1 {
            soa_results[i] = simd_multiply_soa(v, soa_bundles[i]);
        }
    }
    t3 := current_time_monotonic();
    soa_us := to_microseconds(t3 - t2);

    // Verify correctness: extract SoA results and compare
    match := true;
    for i: 0..(NUM_MATRICES / 4)-1 {
        for lane: 0..3 {
            extracted := from_soa(soa_results[i], lane);
            idx := i * 4 + lane;
            for e: 0..15 {
                if abs(aos_results[idx].floats[e] - extracted.floats[e]) > 0.01 {
                    match = false;
                    break;
                }
            }
        }
    }

    print("% matrices, % iterations\n", NUM_MATRICES, ITERATIONS);
    print("Results match: %\n\n", match);
    print("AoS (one-at-a-time): % us\n", aos_us);
    print("SoA (four-at-a-time): % us\n", soa_us);
    if soa_us > 0
        print("Speedup: %x\n", formatFloat(cast(float64) aos_us / cast(float64) soa_us, trailing_width=2));

    print("\nWHY SoA IS BETTER:\n");
    print("  AoS: SIMD lanes = 4 floats of the SAME matrix\n");
    print("       -> speeds up one multiply, but you still loop N times\n");
    print("  SoA: SIMD lanes = same element of 4 DIFFERENT matrices\n");
    print("       -> one call does 4 multiplies, you loop N/4 times\n");
    print("  Same total SIMD instructions, but SoA has better cache\n");
    print("  behavior and less loop overhead.\n");
    print("\n  In real engines, your transforms/particles/bones are stored SoA\n");
    print("  from the start, so the conversion cost doesn't exist.\n");
}

main :: () {
    lesson_1_basics();
    lesson_2_horizontal();
    lesson_3_masks();
    lesson_4_arrays();
    lesson_5_matrix();
    lesson_6_batch();
}
