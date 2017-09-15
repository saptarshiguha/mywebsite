
* mytoc
{:toc}

## Introduction

The objective here is to label figures such as the one below (call the shape of
the graph as 'A') as a banded figure.Now terminology can be varied. One can say
that the density of the observations is clearly bimodal. And indeed it is.

{% include image.html url="images/talos/t1.png" width="55%" %}

 But consider this figure (B),which our algorithm will
observe and need to classify

{% include image.html url="images/talos/t2.png" width="55%" %}

This is case of a level shift. In each regime (or level) the density of the
observations are unimodal but combined the density is definitely bimodal. The
rub here is that the observations are not identically distribution and most
schemes for checking bimodality (or mixtures) assume the data is identically
distributed.

So we have a classification problem and need a way to assign figures such as A
above to the banded class. We have two approaches. Each have aspects to them
that are more intuitive than others.

## Clustering

On the y-axis the observations in A clearly belong to two clusters. The idea is
that if two _distinct_ clusters do exist, then a k-means clustering algorithm
repeated many times (since the k-means is sensitive to seed centers) will be
able to detect such clusters. Indeed it does (with our data). Let's assume we
can assign each observation to 2 detected clusters (these may not be 'real'
clusters). Some observations follow:

1. The classifier is sensitive to the proportion of the two clusters. If one is
   much larger than the other (typical sample size is 60-100 observations) say
   in the ratio of 85:15, then the figure looks like a case of one cluster and
   several outliers. See this figure

    <table class="image" align="center">
    <tr><td align="center"> <img src="{{ site.url }}//images/talos/t4.png" width="65%"/></td></tr>
    </table>

   What we are trying to detect is a regular switching between two generating
   distributions.  So this ratio becomes a parameter. We want to be able detect
   figures with two 'strongly developed' bands.

2. As we'll see in point (4), we have a cutoff based on distance. To make this
   cutoff make sense across all figures which can have different scales, we
   standardize the data to unit scale and zero mean. Also we cap outliers to say
   +/- 4. Though this is a parameter, the rule is not very much affected by it,
   mostly because we don't have too many outliers.

3. As mentioned above, k-means can return different clusters depending on the
   seed. If there are two distinct clusters it is expected that in N
   repetitions, these clusters will appear majority number of times. This N is
   also  a parameter.

4. The k-means algorithm can return false positives. For example, the k-means
   will return two clusters when given data from $Uniform(0,1)$. To identify
   sharply defined clusters we create a 'distance' measure. There are two
   clusters with centers $C_1$ and $C_2$. For a given observation $Y_i$ let it
   be assigned to cluster $C_i$. Then $\frac{ | Y_i - C_i|}{ |Y_i-C_1| + |
   Y_i-C_2|}$ is a measure of how strongly the $Y_i$ belongs to cluster $C_i$. The
   mean of this across all points $Y_i$ is a measure of how strong the
   clustering is. This mean ought to be small.

   We also confirm that means of the observations in each cluster
   are statistically different. *I'm not sure if this second condition is   actually necessary*

5. We also do not want the figures such as B to tagged as banded. There are two approaches.

   a) Assign the points indices 1 to number of observations. If it is a level
   shift then the group of indices in one cluster will have a different center
   than the indices in the second group. A Wilcoxon test will suffice to check
   this. A problem with this, as in the below figure is that it will reject an
   obviously bandied graph that has shown a level shift.

    <table class="image" align="center">
    <tr><td align="center"> <img src="{{ site.url }}//images/talos/t3.png" width="55%"/></td></tr>
    </table>

   b) A way around this is to divide the x-axis into windows of size $h$ and
   compute the above the algorithm for each window. If the measure in (4) are
   acceptable in all the windows, then we can conclude the curve is banded even
   if it has a level shift. This approach will reject figures such as B but
   accept the above figure since it is banded in each window. This approach is
   sensitive to the number of observations in the window and works if we have
   plenty of data. Which is not _always_ the case.

6. Ultimately, we have a rule, once we have clusters, if
    - the means of the cluster sufficiently different?
    - there is no level shift (5a is not rejected)
    - the separation score (defined in (4)) is less than some cut off (in our case 0.14)

    then we consider the figure as banded.

See [this link](http://people.mozilla.org/~sguha/tmp/bandiness.html) (be
patient, 3MB of 220 bokeh plots)  for an example of
figures marked as banded (each plot has a number id:## x1_x2 below it.
Figures with x2==0 are labelled as banded). The code for this is
[https://gist.github.com/anonymous/b182c1a175171117579b](https://gist.github.com/anonymous/b182c1a175171117579b).
There are 220 combinations of platform, test suite and compile options.

## Mixture of Gaussians

This is a statistical model based approach. Here we consider the observations to
be independent and identically distributed (as we'll see we'll handle the not
identical bit in a manner similar to 5(a) above) from

$$
Y_i \sim \lambda_1Normal(\mu_1,\sigma_1)+ (1-\lambda)Normal(\mu_2, \sigma_2)
$$

where $0 < \lambda < 1$. Using the
[mixtools](https://cran.r-project.org/web/packages/mixtools/index.html) package
in R, the above model is fit using an iterative Expectation Maximization(EM)
approach. What it returns us (after several iterations)

- the value of $\lambda$
- the values of $\mu$ and $\sigma$ for each component
- the posterior probabilities of $Y_i$ belonging to each component

We classify an observation $Y_i$ belonging to cluster $C_i$ if the posterior
probability of it belong to cluster $C_i$ is greatest. The classification rule
for this is a bit similar to the the clustering approach.

1. We check that $\lambda$ is not too close to 0 or 1, for then we have a case
   similar to (1) in the clustering approach.
2. In a given cluster (clusters 1 or 2), for every point we compute the
   difference in posterior probability of belonging to component 1 or 2. This is
   averaged across the cluster (for each cluster) and we take the minimum
   value. We apply a cutoff 0.9.  That is in both clusters the average
   probability of belonging to the assigned cluster is more than probability of
   belonging to the other cluster by at least 0.9
3. We apply a similar condition as 5(a) to reject level shifts

A link to these figures can be found(be patient, 3MB of 220 bokeh plots)
[here](http://people.mozilla.org/~sguha/tmp/bandi/alltypes.html). Code for this
is [here](https://gist.github.com/anonymous/c5a0fcf3785ddc589cd7).

A natural question, isn't there a hypothesis test for whether one component is
better than two (or vice versa)? This is a complicated problem and often
involves visual inspection. Using this test and then applying rules (like above)
wouldn't make it much more sophisticated. However this is something I will look
into more.

## Comparison
Using the rules above they both work very well. And indeed

- [this page](http://people.mozilla.org/~sguha/tmp/bandi/kmPos_mixNeg.html) is the list of all platform/test suite/compile options that were
  flagged by kmeans but *not* by the mixture approach
- [this page](http://people.mozilla.org/~sguha/tmp/bandi/kmNeg_mixPos.html) are
  the figures considered by banded by the mixture approach but *not* by the
  kmeans approach.

The

- kmeans approach is fairly easy to understand and implement.
- the mixture model is probabilistic and the rule in (2) for the mixture model is
  easier to understand that the one in (4) for kmeans.
- we do not need to standardize the observations in the mixture method since we
  discriminate on the probability scale. This can be fixed in kmeans by using
  probabilistic clustering.
- both exist in Python.

Given this, *I would recommend  the kmeans approach* since it is very easy to
understand even for someone not familiar with  probability. Moreover, we can expand the
kmeans approach to a probabilistic clustering approach to match something
similar to the mixture component method.

## But When to Use?

So when is this important? We can always not worry about the bimodality and
ignore this information. If we use a t-test to compare means then we increase
the standard error of the test (because the bimodal distribution will have a
larger standard deviation). Thus when comparing new data with old using a t-test
and ignoring bimodality, we tend to *not reject* the null hypothesis of no
change.

But if we are trying to detect very large changes for a group of new
observations , then we not so affected. But this all depends on the nature of
the standard deviation with respect to the means of the reference data.

In general, if we can conclude the data is bimodal, we classify observations to
each component/cluster. We could construct a test with improved efficiency with
this new information.

## Other Methods

The first method that comes to mind is Kernel Density estimation (KDE). In this
approach, the most sensitive parameter is the *bandwidth* $h$. KDE methods can also
be non parametric which removes the Gaussian assumption. Some guiding parameters
would still need to be chosen such as the mixing proportion ($\lambda$ in the
Mixture section)

