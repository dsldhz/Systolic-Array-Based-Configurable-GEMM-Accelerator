import numpy as np
import csv

# params
np.random.seed(1023)
sparsity = 0.35


# convert a signed INT8 number to hexidemical string
def number_to_hex(number):
    if number < 0:
        number = int(number) 
        # convert to two's complement
        number = 256 + number
    return hex(number)[2:].zfill(2)

def reorder_matrix_by_tiles(matrix: np.ndarray, P: int) -> list:
    """
    将一个二维Numpy矩阵按P*P的小块（瓦片）进行重排。
    重排顺序为行主序遍历瓦片，即先遍历完第一行瓦片，再遍历第二行瓦片。

    :param matrix: 输入的二维Numpy矩阵。
    :param P: 瓦片（小块）的边长。
    :return: 一个包含重排后矩阵所有行的Python列表。
    """
    # 1. 获取矩阵维度并进行有效性检查
    N, M = matrix.shape
    if N % P != 0 or M % P != 0:
        raise ValueError(f"矩阵维度 ({N}x{M}) 必须能被瓦片大小 P ({P}) 整除。")

    # 2. 计算瓦片的数量
    num_tiles_high = N // P  # 垂直方向上的瓦片数量
    num_tiles_wide = M // P  # 水平方向上的瓦片数量

    # 3. 创建一个空列表来存储重排后的行
    reordered_rows = []

    print(f"开始重排一个 {N}x{M} 的矩阵，使用 {P}x{P} 的瓦片...")
    print(f"瓦片网格为: {num_tiles_high} 行 x {num_tiles_wide} 列。")

    # 4. 按“行主序”遍历所有瓦片
    for tile_row_idx in range(num_tiles_high):
        for tile_col_idx in range(num_tiles_wide):
            # 4a. 计算当前瓦片在原矩阵中的起始和结束索引
            start_row = tile_row_idx * P
            end_row = start_row + P
            start_col = tile_col_idx * P
            end_col = start_col + P

            # 4b. 使用Numpy切片提取出当前瓦片
            current_tile = matrix[start_row:end_row, start_col:end_col]
            
            # 4c. 将当前瓦片的所有行追加到结果列表中
            # numpy数组可以直接被extend到list中，它会自动按行迭代
            reordered_rows.extend(current_tile)

    return reordered_rows

# Main Entry
def main():
    # create a signed INT8 numpy array with sparsity of 15% and shape of (1000, 1000)
    shape = (1024, 512)
    array = np.random.randint(0, 256, size=shape).astype(np.int8)
    # set values to 0 with 10% probability
    array[np.random.rand(*shape) < sparsity] = 0
    print(array)

    print("\n--- 处理1024x512项目矩阵 ---")
    # 1. 定义参数
    # P值可以根据您的硬件设计来定，例如 16, 32, 或 64
    P = 4
    OUTPUT_FILENAME = "input_mem.csv"

    reordered_data = reorder_matrix_by_tiles(array, P)
    print(f"正在将重排后的数据写入 '{OUTPUT_FILENAME}'...")
    with open(OUTPUT_FILENAME, 'w') as f:
        # 遍历重排后的每一行数据
        for row in reordered_data:
            # 对于当前行中的每一个数字，都调用number_to_hex函数进行转换
            # 然后使用"".join()将所有转换后的2位十六进制字符串无缝拼接起来
            hex_line = "".join([number_to_hex(num) for num in row])
            
            # 将拼接好的整行十六进制字符串写入文件，并手动添加换行符
            f.write(hex_line + '\n')

    print("处理完成！")
    print(f"文件 '{OUTPUT_FILENAME}' 已生成。")
    print(f"文件中的每一行现在是一个由 {len(reordered_data[0]) * 2} 个十六进制字符组成的字符串。")
    np.save('in.npy',array) 
    
if __name__=="__main__": 
    main()