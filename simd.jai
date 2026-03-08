float4 :: SIMD_Array(4, float32);

Matrix4_SoA :: struct {
    e : [4][4] float4;
}

simd_multiply :: (m: Matrix4, v: Vector4) -> Vector4 {
    result: Vector4 = ---;

    for i: 0..3 {
        row: float4 = ---;
        row.data = m.v[i].component;
        vec: float4 = ---;
        vec.data = v.component;
        r := row * vec;
        result.component[i] = r.data[0] + r.data[1] + r.data[2] + r.data[3];
    }

    return result;
}

simd_multiply :: (m: Matrix4, n: Matrix4) -> Matrix4 {
    result: Matrix4 = ---;

    n_row0: float4 = ---;  n_row0.data = n.v[0].component;
    n_row1: float4 = ---;  n_row1.data = n.v[1].component;
    n_row2: float4 = ---;  n_row2.data = n.v[2].component;
    n_row3: float4 = ---;  n_row3.data = n.v[3].component;

    for row: 0..3 {
        r :=  n_row0 * m.coef[row][0]   
            + n_row1 * m.coef[row][1]  
            + n_row2 * m.coef[row][2] 
            + n_row3 * m.coef[row][3];   

        result.v[row].component = r.data;
    }

    return result;
}

matrix_from_soa :: (s : Matrix4_SoA, lane : int) -> Matrix4 {
    result : Matrix4 = ---;
    for row : 0..3 {
        for col : 0..3 {
            result.coef[row][col] = s.e[row][col].data[lane];
        }
    }
    return result;
}

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

simd_multiply_soa :: (left : Matrix4, right : Matrix4_SoA) -> Matrix4_SoA {
    result : Matrix4_SoA = ---;

    for row : 0..3 {
        for col : 0..3 {
            result.e[row][col] =  right.e[0][col] * left.coef[row][0]
                                + right.e[1][col] * left.coef[row][1]
                                + right.e[2][col] * left.coef[row][2]
                                + right.e[3][col] * left.coef[row][3];
        }
    }

    return result;
}

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
