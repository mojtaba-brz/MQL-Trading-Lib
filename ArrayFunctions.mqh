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

template <typename T>
void append_element(T& A[], T value)
{
    int iLast = ArraySize(A);
    ArrayResize(A, iLast + 1);
    A[iLast] = value;
}

template <typename T>
void append_element_struct(T& A[], T &value)
{
    int iLast = ArraySize(A);
    ArrayResize(A, iLast + 1);
    A[iLast] = value;
}

template <typename T>
void swing_element(T& A[], int first_idx, int second_idx)
{
    T temp_struct = A[first_idx];
    A[first_idx]  = A[second_idx];
    A[second_idx] = temp_struct;
}

template <typename T>
bool is_in(T V, T& A[])
{
    for(int i = 0; i < ArraySize(A); i++) {
        if(StringCompare(typename(V), "string") == 0) {
            if(StringCompare(V, A[i]) == 0) {
                return true;
            }
        } else if(V == A[i]) {
                return true;
        }
    }
    return false;
}
//+------------------------------------------------------------------+
