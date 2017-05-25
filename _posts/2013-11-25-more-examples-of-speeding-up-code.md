---
layout: postjournal
title: Using rterra to Speed Up Code I Came Across via Blogs
excerpt: How can rterra be used to improve your code?
tags: terra R performance extension lua luajit
---

{% jrnl width=code %}

* mytoc
{:toc}

## Introduction
The R Bloggers daily email is a nice way to keep oneself informed about the R
world and occasionally learn something nice in Statistics. I came across two
entries on the 23rd

- [Attractors in R](http://www.r-bloggers.com/just-for-fun-attractors-in-r/)
- [Simulating Speed; GNU R vs Julia](http://www.r-bloggers.com/simulatin-speed-gnu-r-vs-julia/)

Both noted the slow speed of R and both had reproducible, short code
snippets. Could rterra improve things here?


## Attractors in R

You might have come across attractors if you've ever computed the sine of a
number of number on a calculator and then the sine of that ... the value it
converges to is an attractor.

The code given takes 24 seconds on computer at my disposal. For reference here
is the code

    clifford <- function(x, y) {
            for (i in 1:npoints) {
                    xn <- sin(a * y) + c * cos(a * x)
                    yn <- sin(b * x) + d * cos(b * y)
                    row <- round(map(xn, -abs(c) - 1, abs(c) + 1, 1, width))
                    col <- round(map(yn, -abs(d) - 1, abs(d) + 1, 1, height))
                    mat[row,col] <<- mat[row,col] + 1
                    x <- xn
                    y <- yn
            }
    }
	cvec <- grey(seq(0, 1, length=10))
    #we end up with npoints * n points
    npoints <- 8
    n <- 100000
    width <- 600
    height <- 600
    #make some random points
    rsamp <- matrix(runif(n * 2, min=-2, max=2), nr=n)
    a <- -1.4
    b <- 1.6
    c <- 1.0
    d <- 0.7
    mat <- matrix(0, nr=height, nc=width)
    system.time(xx <- apply(rsamp, 1, function(x) clifford(x[1], x[2])))
    dens <- log(mat + 1)/round(log(max(mat)))
    par(mar=c(0, 0, 0, 0))
    image(t(dens), col=cvec, useRaster=T, xaxt='n', yaxt='n')


The main function can be rewritten using Lua/Terra as follows

    require("math")
     
    function map(x, imin, imax, omin, omax) 
            return( (x - imin) / (imax - imin) * (omax - omin) + omin )
    end
     
    function clifford(x,y,a,b,c,d,width,height)
       local xn = math.sin(a * y) + c * math.cos(a * x)
       local yn = math.sin(b * x) + d * math.cos(b * y)
       local row = math.floor(0.5+map(xn, -math.abs(c) - 1, math.abs(c) + 1, 0, width-1))
       local col = math.floor(0.5+map(yn, -math.abs(d) - 1, math.abs(d) + 1, 0, height-1))
       return xn,yn,row,col
    end
    doSim = nil
    function doSim(rsamp0,mat0,param)
       local rsamp,mat,p  = R.asMatrix(R.Robj(rsamp0)),R.asMatrix(R.Robj(mat0)),R.Robj(param)
       local a,b,c,d,width,height,npoints = p[0],p[1],p[2],p[3],p[4],p[5],p[6]
       for rows = 0, rsamp.nrows -1 do
          local x,y = rsamp[{rows,0}],rsamp[{rows,1}]
          local row, col
          for i = 1, npoints do
     	 x,y,row,col=clifford(x,y,a,b,c,d,width,height)
     	 mat[{row,col}] =  mat[{row,col}]+1
          end
       end
    end

And we can call it from R as

    library(rterra)
    tinit()
    terraFile("path-to-source-file")
    mat <- matrix(0, nr=height, nc=width)
    system.time(doSim(rsamp, mat, c(a,b,c,d,width,height,npoints)))
    dens <- log(mat + 1)/round(log(max(mat)))
    par(mar=c(0, 0, 0, 0))
    image(t(dens), col=cvec, useRaster=T, xaxt='n', yaxt='n')

And the performance is now ...  0.16 seconds. Very impressive. Dynamically
jitted to amazing speeds. No compile step required.

## Simulating the Speed in R
The other post compared R to Julia. Not all comparisons are equal. For example,
R's `mean` and  `sum` take care of missing values. I'm not sure that Julia
worries about those things. Moreover, R's normal and uniform random number
generator can take quite a bit of time to run. Hence in the code below, I use
GSL's normal and uniform random number generators. The original code takes ~ 8.6
seconds to run. Replacing with Lua/Terra takes 6 seconds. Replacing R's random
number generator with GSL brings it down to ~2 seconds. Not as fast as Julia.

    gsl = terralib.includecstring [[
    #include <gsl/gsl_rng.h>
    #include <gsl/gsl_randist.h>
    const gsl_rng_type* get_mt19937(){
        		return gsl_rng_mt19937;
      	}
    ]]


    terralib.linklibrary "libgsl.so"
    terralib.linklibrary("libgslcblas.so")

     
    cont_run = nil
    function cont_run(params0, tr0,r0,rno)
       local params,tr,r,rn= R.Robj(params0),R.Robj(tr0), R.Robj(r0),R.Robj(rno)
       local reps, l,s,n,d = params[0],params[1],params[2],params[3],params[4]
       -- local runif=R.makeRFunction("myrunif",0)
       local rng = gsl.gsl_rng_alloc(gsl.get_mt19937())
       for i=0, (reps - 1) do
          local sig =  rn[i] --gsl.gsl_ran_gaussian(rng,d)
          local mul = 1
          if( sig < 0) then
     	 sig = -sig
     	 mul = -1
          end
          local s  = 0
          for i=0,#tr-1 do
     	 if sig>tr[i] then s=s+1 end
          end
          r[i] = mul*s/(l*n)
          -- local _x = R.Robj(runif())
          for i=0,n-1 do
     	 if gsl.gsl_rng_uniform (rng) < s then tr[i] = math.abs(r[i]) end
          end
       end
       gsl.gsl_rng_free (rng)
    end

The following is the R code to call the above (assuming it is saved in `al.lua`)

    ## R Code 
    library(rterra)
    tinit()
    terraFile("~/al.lua")
     
    library(e1071)
     burn.in=1000; reps=10000; n=1000; d=0.005; l=10.0; s=0.01
     myrunif <- (function(n) function() runif(n))(n)
     system.time(replicate(10,{
       tr <- rep(0, n)
       r <- rep(0, reps)
       rno <- rnorm(reps, 0, d)
       terra("cont_run",c(reps, l,s,n,d), tr,r,rno)
       kurtosis(r[burn.in:reps])
     }))


I believe that by writing extensions in Lua/Terra many woes of the patient R
programmer will be addressed.

Cheers

{% endjrnl %}
