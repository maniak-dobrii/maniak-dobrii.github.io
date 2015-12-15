---
layout: post
title: 14 Dec 2015 🚲
---

Here goes my first ever code bicycle!

Today it is "rounding" arbitrary double to arbitrary decimal digits. For example, it could transform 1.234 to 1.23, or 0.05 to 0.1.

<!-- language: lang-objc -->
``` objc
double MDMathCeil(double positiveValue, unsigned int decimalDigits)
{
    // hey, it only accepts negative values
    if(positiveValue < 0) return positiveValue;

    // 0.12|6 => 126.0 + 5 = 131.0
    unsigned int divider = (unsigned int)pow(10.0, decimalDigits + 1);
    double d1 = positiveValue * divider + 5.0;

    // 131.0 => 13.1
    d1 /= 10.0;
    // 13.1 => 13.0
    d1 = floor(d1);
    // 13.0 => 0.13
    d1 /= (unsigned int)pow(10.0, decimalDigits/* + 1 - 1*/);

    return d1;
}

```

Where can it be used? Well, for pluralization, guess I should write full article on that.
Note that this works only for positive doubles and will likely overflow the double for big `positiveValue`/`decimalDigits`, but it works perfectly for something like 12345.12345, 5 and a lot above.
