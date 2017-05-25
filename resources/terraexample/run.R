Sys.setenv(INCLUDE_PATH=strsplit(system("R CMD config --cppflags",intern=TRUE),"-I")[[1]][[2]])
dyn.load("a.so")
.Call("initTerrific",NULL)
.Call("terraDoFile","/home/sguha/dev/earth/code2.t")

x=runif(5)
print(x)
.Call("doTerraFunc1","bubbleSort",x)    
## .Call("doTerraFunc1","foo",x)    


require(inline)  ## for cxxfunction()                                                       
src = 'Rcpp::NumericVector vec = Rcpp::NumericVector(vec_in);                               
       double tmp = 0;                                                                      
       int no_swaps;                                                                        
       while(true) {                                                                        
           no_swaps = 0;                                                                    
           for (int i = 0; i < vec.size()-1; ++i) {                                         
               if(vec[i] > vec[i+1]) {                                                      
                   no_swaps++;                                                              
                   tmp = vec[i];                                                            
                   vec[i] = vec[i+1];                                                       
                   vec[i+1] = tmp;                                                          
               };                                                                           
           };                                                                               
           if(no_swaps == 0) break;                                                         
       };                                                                                   
       return(vec);'                                                                        
bubble_sort_cpp = cxxfunction(signature(vec_in = "numeric"), body=src, plugin="Rcpp")  
## bubble_sort_cpp = cppFunction(src)

library(microbenchmark)
vector_size <- 1000
x1 <- as.numeric(sample(1:vector_size))
print(microbenchmark(
        .Call("doTerraFunc1","bubbleSort",x1),
        bubble_sort_cpp(x1),
        sort(x1),control=list(warmup=5)))



