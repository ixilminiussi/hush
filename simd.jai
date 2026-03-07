float4 :: SIMD_Array(4, float32);

// SoA layout: each float4 holds the same matrix element from 4 different matrices.
// e[row][col].data[lane] = matrix_lane's coef[row][col]
Matrix4_SoA :: struct {
    e : [4][4] float4;
}

// Pack up to 4 AoS matrices into one SoA bundle.
// If count < 4, remaining lanes are filled with identity.
matrices_to_soa :: (ms : [] Matrix4) -> Matrix4_SoA {
    assert(ms.count >= 1 && ms.count <= 4);

    result : Matrix4_SoA = ---;
    for row : 0..3 {
        for col : 0..3 {
            for lane : 0..3 {
                if lane < ms.count {
                    result.e[row][col].data[lane] = ms[lane].coef[row][col];
                } else {
                    // pad with identity
                    result.e[row][col].data[lane] = ifx row == col then 1.0 else 0.0;
                }
            }
        }
    }
    return result;
}

// Extract one matrix from a SoA bundle by lane index.
matrix_from_soa :: (s : Matrix4_SoA, lane : int) -> Matrix4 {
    result : Matrix4 = ---;
    for row : 0..3 {
        for col : 0..3 {
            result.coef[row][col] = s.e[row][col].data[lane];
        }
    }
    return result;
}

// Multiply ONE matrix (left) by FOUR matrices packed in SoA (right).
// result[lane] = left * right[lane]  for each lane 0..3
simd_multiply_soa :: (left : Matrix4, right : Matrix4_SoA) -> Matrix4_SoA {
    result : Matrix4_SoA = ---;

    for row : 0..3 {
        for col : 0..3 {
            // result[row][col] = sum_k( left[row][k] * right[k][col] )
            // left[row][k] is a scalar -> broadcasts to all 4 lanes
            // right[k][col] is a float4 -> one value per matrix
            result.e[row][col] =  right.e[0][col] * left.coef[row][0]
                                + right.e[1][col] * left.coef[row][1]
                                + right.e[2][col] * left.coef[row][2]
                                + right.e[3][col] * left.coef[row][3];
        }
    }

    return result;
}

// Convert a flat array of matrices into SoA bundles (groups of 4).
// Caller must free the returned array.
flatten_to_soa :: (matrices : [] Matrix4) -> [] Matrix4_SoA {
    bundle_count := (matrices.count + 3) / 4;
    bundles := NewArray(bundle_count, Matrix4_SoA);

    for i : 0..bundle_count-1 {
        start := i * 4;
        end   := min(start + 4, matrices.count);
        chunk : [] Matrix4;
        chunk.data  = matrices.data + start;
        chunk.count = end - start;
        bundles[i] = matrices_to_soa(chunk);
    }

    return bundles;
}

#import "SIMD";
#import "Math";
