* mytoc
{:toc}

### Introduction

The [Canvasmark](http://www.kevs3d.co.uk/dev/canvasmark/) suite of performance
tests designed to test the "HTML5 canvas rendering performance for commonly
used operations in HTML5 games: bitmaps, canvas drawing, alpha blending, polygon
fills, shadows and text functions." This test consists of 5 tests,

- 3D Rendering - Maths- polygons- image transforms
- Arena5 - Vectors- shadows- bitmaps- text
- Asteroids - Bitmaps
- Asteroids - Bitmaps- shapes- text
- Asteroids - Shapes- shadows- blending
- Asteroids - Vectors
- Pixel blur - Math- getImageData- putImageData
- Plasma - Maths- canvas shapes

The tests are recorded as weighted times, the weights a measure of the
complexity of the test. The final score is the sum of these weighted times.


See
[this page](https://metrics.mozilla.com/protected/shiny/sguha/canvasmark/)(behind
LDAP because of Shiny, sorry) with plots of the subtests across e10s options and
platforms (ignoring non-pgo). The data represents last 90 days (when we have
it). All the replicate data is plotted and the black line is a [loess regression](https://en.wikipedia.org/wiki/Local_regression)
. The band around is a prediction band.


1. The subtests do measure different things as can be observed from
   [this scatter plot](https://docs.google.com/a/mozilla.com/uc?id=0B12g_7yjbdYJM0NCMXdTMTlxY1U&export=download). This
   is reassuring - we don't want duplicate tests.

2. However the scales are widely different ranging from 300-400 for "Asteroids -
   Bitmaps" (OSX10,non e10s) to 1500 - 1700 for the "Pixel Blur ..." test
   (because of the weighting). However, not only are the means vastly different, the
   variation is very different for each. Across operating systems both the means
   and standard errors vary a lot.
   [This figure](https://docs.google.com/a/mozilla.com/uc?id=0B12g_7yjbdYJQjFjMkxGeENCQ0U&export=download)
   is a Box Plot of the test values for different platforms.  We see osx-10-10
   has a lot of spread whereas the others are much less.

3. From the Canvasmark website, the score is arrived at by *adding* these
   figures. If Y is the sum of different values then the variance of Y is the
   sum of the variances of the summands. We are unnecessarily creating a score
   with high variance.

4. Because of (2), % changes in one summand is not equivalent to the same  % change in
   Y e.g. a 10% change in the smallest e.g. "Asteroids - Bitmaps"
   will translate to a much small change in the sum (typically < 1%).

6. On average, the subtests contribute the following to the score.  A breakup by
   platform can be
   [seen here](https://docs.google.com/a/mozilla.com/uc?id=0B12g_7yjbdYJcVdYOVh1ZjlxMXM&export=download)

    |test                                             | contributionpct|
    |:------------------------------------------------|---------------:|
    |Asteroids - Bitmaps                              |           6.845|
    |Asteroids - Shapes- shadows- blending            |           9.190|
    |3D Rendering - Maths- polygons- image transforms |          10.549|
    |Asteroids - Bitmaps- shapes- text                |          11.541|
    |Asteroids - Vectors                              |          13.391|
    |Arena5 - Vectors- shadows- bitmaps- text         |          13.419|
    |Plasma - Maths- canvas shapes                    |          14.544|
    |Pixel blur - Math- getImageData- putImageData    |          20.522|

7. [This link](https://metrics.mozilla.com/protected/shiny/sguha/canvasmark/) is a time series of the canvasmark score across pushes. The
   smooth band is from the standard errors of the loess curve. The smallest
   change we can detect is


### Summary

1. The filtering scheme for canvasmark is to drop first and take the median of
   the remaining. However on inspection, there is nothing remarkable about the
   first (for this test). To get more data, we can easily use all the replicates
   (5) to create 5 canvasmark scores per job rather than one.

2. Because of the very different means, canvasmark really won't measure changes
   in "Asteroids - Bitmaps". For example, in the last 7 days of builds preceding
   2015-11-30, the mean and standard deviation of canvasmark is below. Given
   this , the smallest change you can detect using a t-test and
   12 observations each in the before and after groups at the 1% level is ~
   $qt(1-0.05/2,df=24-2) * sd * \sqrt{\frac{2}{12}}$ or between 187 and  272.
   ~

    |platform    |    Mean| StdDev|
    |:-----------|-------:|------:|
    |linux64     | 6736.25| 161.54|
    |windows7-32 | 8410.36| 236.08|
    |windowsxp   | 8411.45| 187.93|
    |windows8-64 | 8700.39| 214.29|

3.  There is a distinct day of week effect for OS X which manifests itself in in
    creased variance. See this
    [figure](https://docs.google.com/a/mozilla.com/uc?id=0B12g_7yjbdYJOTh4R3ZzeXltVG8&export=download). This
    indicates a QA problem that depends on day of week, which it ought not to or
    should be taken care of.
