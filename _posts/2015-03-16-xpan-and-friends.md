---
layout: postjournal
title: The Interesting XPan and Even More Interesting Friends, also, Quantiles and Discrete Distributions
excerpt: A panoramic view of the city though friends eyes ...
tags: 35mm, xpan, panorama, percentiles
---

{% widepic https://docs.google.com/uc?id=0B6d70FmpKIi1UzRPZ01VdDdnVkU %}
{% jrnl width=code %}

Some math. We have some data $m_1,m_2,m_3,\ldots, m_n$ that are $iid$
$F$. Suppose $x_1,x_2,\ldots, x_k$ are the _unique_ $k$ quantiles of the
data. Note that $k \le n$ because if the data is discrete in some regions of
$F$, the quantiles might be the same. I use the word quantiles but actually
mean the values $x_i = argmin_x P(X \le x) \ge k/M = F_n^{-1}(k/M)$ where $M$
could 100,1000, 2000 etc.

Then define $S = \{ 0,1,2,\ldots, M\}$ and $x^*_i = \\{s \in S: x_i =
F_n^{-1}(s/M)\\}$. Let's take an example.

## Sample from Continuous Data
Consider

    x = runif(100)

then the 10 unique quantiles corresponding to $1/10,\ldots,10/10$ are given by
`unique(quantile(x))` which for this case is going to be `quantile(x)`. They are
all unique. If $x_1$ be the first quantile (corresponding to $1/10$) then $x^*_1
= \\{ 1 \\}$.

## Sample from  Discrete Data
Consider the following data (R code)

    x = sample(c(1,2,3),100, replace=TRUE)

Then, the unique quantiles are `unique(quantile(x,1:10/10))` which is

    [1] 1 2 3

and then

<div>
\begin{align*}
x^*_1 &= \{s \in 1\ldots 10 :  x_1 = F^{-1}_n( s/10) \} =  \{1,2,3\} \\ 
x^*_2 &= \{s \in 1\ldots 10 :  x_2 = F^{-1}_n( s/10) \} =  \{4,5,6\} \\ 
x^*_3 &= \{s \in 1\ldots 10 :  x_3 = F^{-1}_n( s/10) \} =  \{7,8,9,10\} 
\end{align*}
</div>

So what is this all about? Consider a sample from the Normal(0,1) distribution,
and compute it's ECDF $F_n$, then given another sample $Y$ from the Normal(0,1)
distribution, $F_n(Y)$ is going to be uniformly distributed on $[0,1]$. Hence
the average of this is going to be 0.5. By comparing the expectations of
$E(F_n(Y'))$ for different distributions we can compare them to the baseline
distribution i.e. Normal(0,1) (in this case). Technically, the theorem is not a
n&s one, so to be precise if the expectation is not half, then $Y'$ is not
distributed as $F$, but if the expectation is half, well, it doesn't imply that
$Y'$ is distributed as $F$.

It is equivalent to use the indices in the set S (defined above) as opposed the
probabilities from $F_n$. But how do we handle the discrete case (which will
have duplicates in the quantiles)?

## Implementation

Once again, consider the unique quantiles $x_1,x_2,\ldots,x_k$ and add to it
$x_0 = -\infty$ and $x_{k+1}=\infty$. Then let
$G=$ `findInterval(.,all.inside=TRUE)` where $\text{findInterval}$ is the
R function.

<div>
\begin{align}
G(y,\{x_0,x_1,\ldots,x_{k+1}\}) = j+1 \qquad x_j \le y \lt x_{j+1} 
\end{align}
</div>

and 

<div>
\begin{align*}
I(y) = \text{Discrete Uniform Sample of Size 1 from } x^*_{G(y) - 1 }
\end{align*}
</div>

<div>
and $x^*_0$ is the set containing only 0. Also observe $\cup_{i=1}^k x^*_i = \{1,2,\ldots,M\}$ .
So consider again the continuous distribution: take a sample, compute the unique quantiles $x_i$ and the sets $x^*_i$ . Note, that
$|x^*_i| = 1$.If we apply $I$ to a new sample $y_j$ from the same distribution,
we will obtain roughly a uniform distribution on  the numbers $1,2,\ldots, M$.
Consider the discrete case, for which the cardinality of some of the $x^*_i$ is greater than
1. In this case we randomly sample from the set $I(y_j)$, so if the sample size of
$y$ is very large, we will be uniformly sampling across $\\{1,2,\ldots, M\\}$.
If the distribution of $y$ is say to the right of $x$, then the distribution of
the $I(y)$'s will be correspondingly shifted right. If there are some $y$'s
which are less than $\min x$ we will have a lot of zeroes and the distribution
of $I(y)$ will be shifted left.
</div>

## But why ...

At Mozilla, we have a slew of measurments, see
[this website](http://mxr.mozilla.org/mozilla-central/source/toolkit/components/telemetry/Histograms.json).
I was asked to create some indices of the `CYCLE_COLLECTOR*` measures. Index
creation is varied and one method I haven't seen is comparing the data of a new
population to the distribution of a reference population using the above
method. The typical methods are based on normalization and essentially comparing
on the standard deviation scale. Using the index method, i need not worry about
outliers, or the shape of the distributions. The approach i'm thinking of involves

- take a reference population, say WINNT, 32 bit, Firefox v35 (A)
- compute the unique quantiles of `CYCLE_COLLECTOR_COLLECTED` (for example)
- use the above method to compute $I(y)$ for the `CYCLE_COLLECTOR_COLLECTED` data from another population (B)
- and use some summary statistic to compare $I(y)$ for the data for B with the
$I(y)$ for A ( applying $I$ to the data for A will result in a uniform
distribution)

That is just for one measure, i need a way to combine all the `CYCLE_COLLECTOR*`
measures into one `CYCLE_COLLECTION` index.

## Code

```R
.assign.bucket <- function(xp, M){
    ## xp is a vector of numbers
    ## xp can be data table, in which case 'x' are the values of X and
    ## 'n' is their frequency
    x                 <- as.numeric(c(-Inf,if(is(xp,"data.table"))
        xp[,wtd.quantile(x,n, 1:M/M)]
    else
        quantile(xp, 1:(M)),Inf))
    xu                <- sort(unique(x))
    xt                <- format(x, trim=TRUE,nsmall=20)
    xstar             <- split(1:(M+2), xt)
    xstar             <- xstar[order(as.numeric(names(xstar)))]
    allcont           <- all( unlist(lapply(xstar, length))==1)
    structure(
        if(allcont)
            function(y,...)
                findInterval(y,xu,all.inside=TRUE) -1
        else
            function(y,bk=FALSE) {
                X     <- findInterval(y, xu,all.inside=TRUE,rightmost.closed=TRUE)
                if(bk) return(X)
                sapply(X, function(yp)  {
                    z <- xstar[[ yp ]]-1
                    if(length(z)==1) z else sample(z,1)
                })}
      , src = x, xstar=xstar)

xp                    <- sample(c(1,2), 4000,replace=TRUE)
h                     <- pmethod(xp,10)
yp                    <- sample(c(1,2), 40000,replace=TRUE)
yps                   <- h(yp)
round(prop.table(table(yps))*100,1)
}
```

## Future Work
The above assumes we have at least two distinct $x_i$ apart from $\infty$ and $-\infty$.
Compute standard errors for what ever summary statistic I use in the above steps.


# Photos

As always, I like to leave people with photos.  The photos below were
taken with an XPan using Kodak 800 and TriX-400. The square pictures were with a
hasselblad on Portra 160(?, could be 400).  On the whole I'm quite a fan of
Photoworks, San Francisco. Their scan quality is very good though slightly
overpriced. Now does that mean i lose myself down the rabbit hole of flatbed
scanning? Well, not exactly, I've gone and gotten myself a Pakon scanner. Which
thankfully is not such a rabbit hole as i might have thought. More on that
later.
{% endjrnl %}


{% imgtile nc=1 w=6 %}
https://docs.google.com/uc?id=0B6d70FmpKIi1OUVldzVIN281YUE 
{% endimgtile %}

{% imgtile nc=1 w=6 %}

https://docs.google.com/uc?id=0B6d70FmpKIi1VnJ6N3hQamZTUnc https://docs.google.com/uc?id=0B6d70FmpKIi1Wjc1VFhxeVhmY1k 
https://docs.google.com/uc?id=0B6d70FmpKIi1UElLZ1dVNzRPOXc https://docs.google.com/uc?id=0B6d70FmpKIi1cmdyTEdEOFdDWVU 
https://docs.google.com/uc?id=0B6d70FmpKIi1UU1NV0RpRy15YWM https://docs.google.com/uc?id=0B6d70FmpKIi1ZlJSZHJRbGVZS0U 
{% endimgtile %}

{% imgtile nc=2 w=8 %}
https://docs.google.com/uc?id=0B6d70FmpKIi1VERxeERheXBfcVk https://docs.google.com/uc?id=0B6d70FmpKIi1cThUU2prNGZHTjQ 
https://docs.google.com/uc?id=0B6d70FmpKIi1eDNhMkUyNGVWREE https://docs.google.com/uc?id=0B6d70FmpKIi1NUdmMHlYeUE1MlE 
https://docs.google.com/uc?id=0B6d70FmpKIi1NXR3XzctMW40aEk https://docs.google.com/uc?id=0B6d70FmpKIi1akZCQWh2R2xrWEU 
https://docs.google.com/uc?id=0B6d70FmpKIi1X21aOXg0UWktZlU https://docs.google.com/uc?id=0B6d70FmpKIi1N0JDVGF6Q0pDM28 
https://docs.google.com/uc?id=0B6d70FmpKIi1cXpLSG5tV1lYLTA https://docs.google.com/uc?id=0B6d70FmpKIi1X2FEdFlkX3pzNXc 
https://docs.google.com/uc?id=0B6d70FmpKIi1dkhBRE9CY2dVNEk https://docs.google.com/uc?id=0B6d70FmpKIi1WDFkdXktNjNsUm8 
https://docs.google.com/uc?id=0B6d70FmpKIi1amh2OVVQTG41MVU https://docs.google.com/uc?id=0B6d70FmpKIi1SmhwaFk1TTNFdHM 
https://docs.google.com/uc?id=0B6d70FmpKIi1MHhjNUxJUTJUM2M https://docs.google.com/uc?id=0B6d70FmpKIi1YTk2a3NoYVhHa1U 
https://docs.google.com/uc?id=0B6d70FmpKIi1MmhEUm1TVk5LcUE https://docs.google.com/uc?id=0B6d70FmpKIi1dFRkRXJhLWpEdEE 
https://docs.google.com/uc?id=0B6d70FmpKIi1c0RXeEtWc0pJUlE https://docs.google.com/uc?id=0B6d70FmpKIi1NnZweUVSUl9SSE0 
https://docs.google.com/uc?id=0B6d70FmpKIi1Zng0Ml80T1FPUm8 https://docs.google.com/uc?id=0B6d70FmpKIi1aDR1TWFkLXRHaGs 
https://docs.google.com/uc?id=0B6d70FmpKIi1STh1WHgxMEw1c28 https://docs.google.com/uc?id=0B6d70FmpKIi1blppSWlUZXBVMkk 
{% endimgtile %}

{% imgtile nc=3 w=9 %}
https://docs.google.com/uc?id=0B6d70FmpKIi1aVEyT19RcG5vSjg https://docs.google.com/uc?id=0B6d70FmpKIi1ajdqS3lfYzBCTGM 
https://docs.google.com/uc?id=0B6d70FmpKIi1VHVjQXM0YnFIY2M https://docs.google.com/uc?id=0B6d70FmpKIi1b0k4NzlhTWpKLW8 
https://docs.google.com/uc?id=0B6d70FmpKIi1Tkp1SS1xMHVXdUk https://docs.google.com/uc?id=0B6d70FmpKIi1OFhzUUc0MFNKNHc 
{% endimgtile %}

{% imgtile nc=1 w=8 %}
https://docs.google.com/uc?id=0B6d70FmpKIi1VDZ6U0VaWUdvSGM 
https://docs.google.com/uc?id=0B6d70FmpKIi1WkhaaTFxMDIxblU https://docs.google.com/uc?id=0B6d70FmpKIi1OTRYS3VpME0weTQ 
https://docs.google.com/uc?id=0B6d70FmpKIi1YVpzQzk1bk5FYTA https://docs.google.com/uc?id=0B6d70FmpKIi1b2VMcmkzMEo3QUE 

{% endimgtile %}


{% widepic  https://docs.google.com/uc?id=0B6d70FmpKIi1RnVfek5qc1BNWDQ  %}


{% imgtile nc=1 w=8 %}
https://docs.google.com/uc?id=0B6d70FmpKIi1bEFrVkVUVDRpQmM https://docs.google.com/uc?id=0B6d70FmpKIi1Qy1TTG9OUjBaMFk 
https://docs.google.com/uc?id=0B6d70FmpKIi1UzJBY2g5Y19aSnM https://docs.google.com/uc?id=0B6d70FmpKIi1S1I2dm1SN3hBaFU 
{% endimgtile %}

{% imgtile nc=2 w=8 %}
https://docs.google.com/uc?id=0B6d70FmpKIi1M2xuNlhqMk1XN0E 
https://docs.google.com/uc?id=0B6d70FmpKIi1ZXkxZ1E0bTlxWlE 
{% endimgtile %}


{% imgtile nc=1 w=8 %}

https://docs.google.com/uc?id=0B6d70FmpKIi1dUVfc2IxN3lYa1E https://docs.google.com/uc?id=0B6d70FmpKIi1UWh3ZnZWeThiVjQ 
https://docs.google.com/uc?id=0B6d70FmpKIi1eVQySjNCd0hCWnc https://docs.google.com/uc?id=0B6d70FmpKIi1c3NDTUQtRXhfRkU 
https://docs.google.com/uc?id=0B6d70FmpKIi1bjVkbEU1OVQ4Wjg https://docs.google.com/uc?id=0B6d70FmpKIi1R0VxYWJCdmVPLW8 
https://docs.google.com/uc?id=0B6d70FmpKIi1dlV2NG95NnRYTkk https://docs.google.com/uc?id=0B6d70FmpKIi1MHJyc3ZsWkpZakU 
https://docs.google.com/uc?id=0B6d70FmpKIi1OGNGcm1ENHkzeXc https://docs.google.com/uc?id=0B6d70FmpKIi1bnlYLVBDSVBZYTA 
https://docs.google.com/uc?id=0B6d70FmpKIi1cTFCODRhZlg1blk https://docs.google.com/uc?id=0B6d70FmpKIi1NDVva0g0Q0YzSnM 
https://docs.google.com/uc?id=0B6d70FmpKIi1R043Unc2REVsc1k https://docs.google.com/uc?id=0B6d70FmpKIi1V0h6ZTVBcnRzNHc 
https://docs.google.com/uc?id=0B6d70FmpKIi1MTFlbmhUY2tUaDQ https://docs.google.com/uc?id=0B6d70FmpKIi1dExQNDlkZ1JFOHM 
https://docs.google.com/uc?id=0B6d70FmpKIi1dVdUWU5jM0lkUVE https://docs.google.com/uc?id=0B6d70FmpKIi1SjdMQ0tSNWw0UEE 
{% endimgtile %}
