class CorrelationCalculator {
    double signal1[], signal2[];
    double sum1, sum2, sum1Sq, sum2Sq, sumProd;
    int _N, index;

public:
    CorrelationCalculator(int N) {
      _N = N;
      index = 0;
      sum1 = 0;
      sum2 = 0;
      sum1Sq = 0;
      sum2Sq = 0;
      sumProd = 0;
      ArrayResize(signal1, N);
      ArrayResize(signal2, N);
    }

    void addData(double data1, double data2) {
        sum1 -= signal1[index];
        sum2 -= signal2[index];
        sum1Sq -= signal1[index] * signal1[index];
        sum2Sq -= signal2[index] * signal2[index];
        sumProd -= signal1[index] * signal2[index];

        signal1[index] = data1;
        signal2[index] = data2;
        sum1 += data1;
        sum2 += data2;
        sum1Sq += data1 * data1;
        sum2Sq += data2 * data2;
        sumProd += data1 * data2;

        index = (index + 1) % _N;
    }

    double getCorrelation() {
        double mean1 = sum1 / _N;
        double mean2 = sum2 / _N;
        double stdDev1 = sqrt(sum1Sq / _N - mean1 * mean1);
        double stdDev2 = sqrt(sum2Sq / _N - mean2 * mean2);
        double correlation = MathMax(-1, MathMin(1, (sumProd / _N - mean1 * mean2) / MathMax((stdDev1 * stdDev2), 1e-200)));
        return correlation;
    }
};
