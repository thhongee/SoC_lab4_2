# Execute FIR code in user BRAM

## Simulation for FIR
```sh
cd ~/caravel-soc_fpga-lab/lab-exmem-fir/testbench/counter_la_fir
source run_clean
source run_sim
```

## TODO list:
```
1. c firmware code. (different from lab4_1, we need to transmit the input data and accept output data)
2. hardware design that manages the wishbone hankshake to access bram. (same as lab4_1)
3. hadrware design that adjusts the wishbone interface to AXI-lite and AXI-Stream interface.
4. hardware design of Wishbone decoder. (We need to connect the wishbone to design 2 and design 3)
5. The fir design should run 2~3 times.  
```

## 協作者github指令:

首先，把project複製下來
> git clone git@github.com:ZheChen-Bill/SoC_Design_Lab4_2.git

開一個branch，這代表著你自己的開發線

>git branch < your branch name >\
>git checkout < your branch name >

然後打指令確認自己切換到自己的branch

>git branch

不要在main branch底下做事情

然後就可以開始寫自己東西

>git add . \
>git commit -m "your commit message" \
>git push origin < your branch name >

第一次push的時候的指令
> git push --set-upstream origin < your branch name >

如果遠端的main branch的code有更新，請將更新載到自己的local端

>git pull origin main

自己的部份寫好之後
>git push

然後通知repository 管理者提交pull request 並merge 進度
