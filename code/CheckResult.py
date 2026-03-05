import numpy as np

# --- Helper Function for reading SINT8 hex files ---
def hex_to_sint8(hex_str: str) -> int:
    number = int(hex_str, 16)
    if number > 127:
        number = number - 256
    return number

def read_hex_mem_sint8(fileName: str, row: int, col: int) -> np.ndarray:
    """读取无分隔符的SINT8十六进制文件 (如 reordered_mem.csv)"""
    shape = (row, col)
    array = np.zeros(shape, dtype=np.int8)
    with open(fileName, "r") as f:
        lines = f.readlines()
    array_idx = 0
    
    for i, line in enumerate(lines):
        line = line.strip()
        if not line:
                continue
            
        if array_idx >= row:
            print(f"Warning: File contains more than {row} non-empty lines. Ignoring extras.")
            break
        if len(line) < col * 2:
            print(f"Warning: Skipping malformed line {array_idx + 1}. Expected {col*2} chars, but found {len(line)}.")
            continue
        for c in range(col):
            # 从行字符串中切片出2个字符
            hex_byte = line[c*2 : c*2+2]
            array[i, c] = hex_to_sint8(hex_byte)
    return array

# --- Helper Function for reordering (needed for input verification) ---
def reorder_matrix_by_tiles(matrix: np.ndarray, P: int) -> np.ndarray:
    """将矩阵按P*P瓦片重排"""
    N, M = matrix.shape
    if N % P != 0 or M % P != 0:
        raise ValueError(f"Matrix dimensions ({N}x{M}) not divisible by tile size P ({P}).")
    num_tiles_high, num_tiles_wide = N // P, M // P
    reordered_rows = []
    for tile_row_idx in range(num_tiles_high):
        for tile_col_idx in range(num_tiles_wide):
            start_row, end_row = tile_row_idx * P, (tile_row_idx + 1) * P
            start_col, end_col = tile_col_idx * P, (tile_col_idx + 1) * P
            current_tile = matrix[start_row:end_row, start_col:end_col]
            reordered_rows.extend(current_tile)
    return np.array(reordered_rows, dtype=matrix.dtype)

# --- NEW Helper Functions for parsing SINT32 results ---
def hex_to_sint32(hex_str: str) -> int:
    """将8位十六进制字符串转换为SINT32数值"""
    number = int(hex_str, 16)
    # 检查32位数的最高位（符号位）
    if number & 0x80000000:
        number = number - 0x100000000
    return number

def read_result_sint32(fileName: str, rows: int, cols: int) -> np.ndarray:
    """读取逗号分隔的SINT32十六进制结果文件"""
    print(f"Reading SINT32 result file: {fileName}")
    shape = (rows, cols)
    array = np.zeros(shape, dtype=np.int64) # Use int64 for safety
    
    with open(fileName, "r") as f:
        lines = f.readlines()
        
    for r, line in enumerate(lines):
        hex_values = line.strip().split(',')
        for c, hex_val in enumerate(hex_values):
            if hex_val:
                array[r, c] = hex_to_sint32(hex_val)
    return array

# --- Main Entry ---
def main():

    print("--- Verifying reordered input file ---")
    P_input = 4 
    MATRIX_DIM = 512
    row =MATRIX_DIM*MATRIX_DIM*2/P_input

    original_array = np.load("in.npy")
    py_reordered_array = reorder_matrix_by_tiles(original_array, P_input)
    file_reordered_array = read_hex_mem_sint8(fileName="input_mem.csv", row=int(row), col=P_input)

    if np.array_equal(py_reordered_array, file_reordered_array):
        print("Input file sanity check: PASSED!")
    else:
        print("Input file sanity check: FAILED!")
    

    print("\n--- Calculating Correct Result ---")
    a1 = original_array[0:MATRIX_DIM, :]
    a2 = original_array[MATRIX_DIM:MATRIX_DIM*2, :]

    # 使用int64进行计算以确保无溢出
    correct_result = np.matrix(a1).astype(np.int64) * np.matrix(a2).astype(np.int64)
    print("Correct reference calculation complete.")


    # --- 3. 读取硬件仿真结果并检查正确性 ---
    print("\n--- Verifying Hardware Result ---")
    
    # 使用新的函数读取SINT32结果文件
    result_array = read_result_sint32(fileName="result_mem.csv", rows=MATRIX_DIM, cols=MATRIX_DIM)
        
    # 计算误差
    loss = np.sum(np.square(correct_result - result_array))
    sum_square_correct = np.sum(np.square(correct_result))
    
    if sum_square_correct == 0:
        relative_loss = "N/A (correct result is all zeros)"
    else:
        relative_loss = loss / sum_square_correct
    
    print(f"\n>> Final SSE Loss is: {loss}")
    if loss == 0:
        print(">> Result is LOSSLESS! Congratulations!")
    print(f">> Relative Loss is: {relative_loss}")

if __name__ == "__main__":
    main()