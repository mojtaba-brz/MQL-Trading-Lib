
int flip_a_coin()
{
   // 0: head
   // 1: tail
   
   int rnd_i = MathRand();
   return rnd_i > 16383? 1:0;
}