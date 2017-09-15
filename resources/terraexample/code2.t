local ffi = require("ffi")

terralib.linklibrary("/usr/lib/R/lib/libR.so")

Rmath = terralib.includec("Rmath.h")
Rinternals = terralib.includec("Rinternals.h")
Cstring = terralib.includec("string.h")
C = terralib.includec("stdio.h")

terra x( what :int, l :int)
   var a =  Rinternals.Rf_allocVector(what, l)
end

-- for k,v in pairs(Rmath) do print(k,v) end
-- for k,v in pairs(Rinternals) do print(k,v) end
-- print(Rinternals.fabsf(10.121))

terra myTfunc( da :&double, l :int)
   for i=0,l do
      print(da[i])
   end
end
function indexAt(a)
   print(Rinternals.Rf_VectorIndex(a,0))
end
	 
terra myfunc(a :&Rinternals.SEXPREC  )
   print(Rinternals.TYPEOF(a))
   myTfunc(Rinternals.REAL(a),Rinternals.LENGTH(a))
end



terra bubbleSort( a :&Rinternals.SEXPREC ): &Rinternals.SEXPREC
   var itemCount:int = Rinternals.LENGTH(a)
   var hasChanged : bool
   var ac : &Rinternals.SEXPREC = Rinternals.Rf_allocVector(14,itemCount)
   Rinternals.Rf_protect(ac)
   -- do a memcpy
   ffi.copy(Rinternals.REAL(ac), Rinternals.REAL(a), itemCount*8)
   var A : &double = Rinternals.REAL(ac)
   repeat
      hasChanged = false
      itemCount = itemCount - 1
      for i = 0, itemCount do
   	 if A[i] > A[i + 1] then
   	    @(A+i), @(A+i + 1) = A[i + 1], A[i]
   	    hasChanged = true
   	 end
      end
   until hasChanged == false
   Rinternals.Rf_unprotect(1)
   return(ac)
end

function a(b)
   local c = bubbleSort(b)
   print(type(c))
   return c
end
