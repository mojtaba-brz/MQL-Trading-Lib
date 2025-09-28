#define MAX_MATH_RAND_VALUE (32767)

int get_rand_int(int max_val)
{
    int rnd_i = MathRand();
    int periods = (int)((1. * MAX_MATH_RAND_VALUE)/max_val);
    rnd_i = (rnd_i/periods);
    return rnd_i;
}