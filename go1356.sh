#! /bin/sh
# This code just allow MLUCM to take more inputs for building height variability, so the results should be the same
ffn="1356"
hmax="37" # currently won't allow non-integer
hstd='5.6'

sed -i'' -e "s/parameter (nzc=16)/parameter (nzc=$hmax)/" column.f90

make clean
make
# maximum building height -> std28 - 20, std56 - 24, 1328 - 26.5, 3328 - 21, 1356 - 37, 3356 - 26


echo "Testing scenario" $ffn
echo "Maximum building height" $hmax

# sed -i  "s/16.0 1.0/$hmax 1.0/" input_column.dat
sed -i'' -e  "s/ 0 16/ $hstd $hmax/" input_column.dat
sed -i'' -e  "s/parameter (nzc=16)/parameter (nzc=$hmax)/" column.f90

cp ${ffn}"/"0625.dat lpz.dat
cp a${ffn}"/"0625.dat ss.dat
./Run_1Dcol
mv output_final.out ${ffn}output_final0625.out
mv topo.out ${ffn}topo0625.out
mv CkLkM_verPro.out ${ffn}CkLkM_verPro0625.out
mv TKEbudget.out ${ffn}TKEbudget0625.out
mv Mombudget.out ${ffn}Mombudget0625.out



cp ${ffn}/1111.dat lpz.dat
cp a${ffn}"/"1111.dat ss.dat
sed -i'' -e  's/0625/1111/' lambdaP.dat
sed -i'' -e  's/48 48/32 32/' input_column.dat 
./Run_1Dcol
mv output_final.out ${ffn}output_final1111.out
mv topo.out ${ffn}topo1111.out
mv CkLkM_verPro.out ${ffn}CkLkM_verPro1111.out
mv TKEbudget.out ${ffn}TKEbudget1111.out
mv Mombudget.out ${ffn}Mombudget1111.out

cp ${ffn}/1600.dat lpz.dat
cp a${ffn}"/"1600.dat ss.dat
sed -i'' -e  's/1111/1600/' lambdaP.dat
sed -i'' -e  's/32 32/24 24/' input_column.dat 
./Run_1Dcol
mv output_final.out ${ffn}output_final1600.out
mv topo.out ${ffn}topo1600.out
mv CkLkM_verPro.out ${ffn}CkLkM_verPro1600.out
mv TKEbudget.out ${ffn}TKEbudget1600.out
mv Mombudget.out ${ffn}Mombudget1600.out


cp ${ffn}/2500.dat lpz.dat
cp a${ffn}"/"2500.dat ss.dat
sed -i'' -e  's/1600/2500/' lambdaP.dat
sed -i'' -e  's/24 24/16 16/' input_column.dat
./Run_1Dcol
mv output_final.out ${ffn}output_final2500.out
mv topo.out ${ffn}topo2500.out
mv CkLkM_verPro.out ${ffn}CkLkM_verPro2500.out
mv TKEbudget.out ${ffn}TKEbudget2500.out
mv Mombudget.out ${ffn}Mombudget2500.out


cp ${ffn}/3500.dat lpz.dat
cp a${ffn}"/"3500.dat ss.dat
sed -i'' -e  's/2500/3500/' lambdaP.dat
sed -i'' -e  's/16 16/11 11/' input_column.dat 
./Run_1Dcol
mv output_final.out ${ffn}output_final3500.out
mv topo.out ${ffn}topo3500.out
mv CkLkM_verPro.out ${ffn}CkLkM_verPro3500.out
mv TKEbudget.out ${ffn}TKEbudget3500.out
mv Mombudget.out ${ffn}Mombudget3500.out


cp ${ffn}/4444.dat lpz.dat
cp a${ffn}"/"4444.dat ss.dat
sed -i'' -e  's/3500/4444/' lambdaP.dat
sed -i'' -e  's/11 11/8 8/' input_column.dat
./Run_1Dcol
mv output_final.out ${ffn}output_final4444.out
mv topo.out ${ffn}topo4444.out
mv CkLkM_verPro.out ${ffn}CkLkM_verPro4444.out
mv TKEbudget.out ${ffn}TKEbudget4444.out
mv Mombudget.out ${ffn}Mombudget4444.out


cp ${ffn}/6400.dat lpz.dat
cp a${ffn}"/"6400.dat ss.dat
sed -i'' -e  's/4444/6400/' lambdaP.dat
sed -i'' -e  's/8 8/4 4/' input_column.dat 
./Run_1Dcol
mv output_final.out ${ffn}output_final6400.out
mv topo.out ${ffn}topo6400.out
mv CkLkM_verPro.out ${ffn}CkLkM_verPro6400.out
mv TKEbudget.out ${ffn}TKEbudget6400.out
mv Mombudget.out ${ffn}Mombudget6400.out






# reset 
if ! sed -i'' -e  's/6400/0625/' lambdaP.dat; then
echo "Failed reset density, check lambdaP.dat"
else
echo "successfully reset density"
fi

if ! sed -i'' -e  's/4 4/48 48/' input_column.dat; then
echo "Failed reset bw, check input_column.dat"
else
echo "successfully reset bw"
fi


if ! sed -i'' -e  "s/ $hstd $hmax/ 0 16/" input_column.dat; then
echo "Failed reset hstd and hmax, check input_column.dat"
else
echo "successfully reset Hstd and Hmax"
fi

if ! sed -i'' -e  "s/parameter (nzc=$hmax)/parameter (nzc=16)/" column.f90 ; then
echo "Failed reset nzc, column.f90"
else
echo "successfully reset nzc"
fi
