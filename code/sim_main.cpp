#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vtestbench_top.h"  // 自动生成的头文件

int main(int argc, char** argv){
  // 初始化环境、设计模块和波形记录器
  VerilatedContext* context = new VerilatedContext;
  VerilatedVcdC*    trace   = new VerilatedVcdC;
  Vtestbench_top*   design  = new Vtestbench_top;  // 注意类名前缀"V"
  
  // 配置波形记录
  context->traceEverOn(true);  // 启用波形跟踪
  design->trace(trace, 3);     // 设置跟踪深度为3级
  trace->open("wave.vcd");     // 输出波形文件
  
  // 主仿真循环
  while (!context->gotFinish()){
    design->eval();            // 更新电路状态
    trace->dump(context->time()); // 记录当前时刻波形
    context->timeInc(1);       // 时间步进+1单位
  }
  
  // 清理资源
  trace->close();
  delete design;
  return 0;
}