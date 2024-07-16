//+------------------------------------------------------------------+
//|                                               ArrayFunctions.mqh |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

template <typename T> void EraseOrdered(T& A[], int iPos)
   {
    int iLast;
    for(iLast = ArraySize(A) - 1; iPos < iLast; ++iPos)
        A[iPos] = A[iPos + 1];
    ArrayResize(A, iLast);
   }

template <typename T>
void Erase(T& A[], int iPos)
   {
    int iLast = ArraySize(A) - 1;
    A[iPos] = A[iLast];
    ArrayResize(A, iLast);
   }
