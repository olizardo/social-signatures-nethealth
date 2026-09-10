# **The Persistent Architecture of Relational Investment: Social Signatures in the NetHealth Study**

**Omar Lizardo**  
*Department of Sociology, University of California, Los Angeles*  
*NetHealth Research Collaboration*

---

## Abstract

How do individuals allocate cognitive, temporal, and emotional bandwidth across their personal networks? Using high-resolution digital call records paired with 8-wave longitudinal network and psychometric surveys from the NetHealth study (*N* = 491 egos, 498,237 communication events), this paper investigates the structure, temporal stability, and psychological foundations of **social signatures**—the ranked proportion of communication effort allocated across alters within discrete temporal windows. We demonstrate that the core signature persistence hypothesis holds across multiple timescales (academic years, semesters, quarters, months, and rolling weekly windows): intra-individual self-divergence (*d*~self~) is uniformly and overwhelmingly smaller than inter-individual reference divergence (*d*~ref~, *p* < 0.0001 across all resolutions). Parametric evaluations confirm that power-law models (*p*(*r*) ~ *r*^-*α*^, mean *R*^2^ = 0.935) fit empirical signatures significantly better than exponential decay models, with ego-specific decay exponents (*α*) converging to an asymptotic value within 6 to 8 months of continuous observation. Going beyond previous work, we introduce three substantive theoretical expansions: (1) **Social Support Grounding**: Linking communication ranks to multi-dimensional survey nominations (*N* = 13,174 dyads), we reveal that the steep drop in communication effort corresponds to sharp qualitative transitions from family-dominated instrumental and emotional support (Rank 1: 69.7% kin, 85.4% emotional support, 87.6% advice) to friend-dominated companionship at lower ranks; (2) **The Slot-Filling Dynamic**: We show that high signature stability persists despite massive alter turnover (averaging 80.1% across semesters), providing direct evidence that college students replenish relational slots with new alters rather than restructuring their overall allocation profile; and (3) **Psychological Determinants**: Using longitudinal mixed-effects and cross-sectional models, we demonstrate that Negative Emotionality strongly predicts steeper, hyper-concentrated signatures (*β* = 0.098, *p* < 0.0001), revealing that elevated negative emotionality drives disproportionate reliance on core ties.

---

## 1. Introduction and Theoretical Background

A central premise in evolutionary anthropology and structural sociology is that human sociality is governed by cognitive and temporal limits on relational investment (Dunbar 1992, 1998; Miritello et al. 2013). While an individual may recognize hundreds of acquaintances, active personal networks are structured into concentric, hierarchical layers: an intimate core of 1 to 2 primary confidants, a sympathy group of approximately 5 close ties, an affinity group of 12 to 15 active alters, and expanding outer circles of declining emotional intensity (Dunbar 2018; Roberts et al. 2009; Sutcliffe et al. 2012).

In a foundational contribution, Saramäki et al. (2014) operationalized this relational hierarchy as an individual's **social signature**: the relative distribution of communication effort that an individual (ego) directs toward their alters, ordered from most-frequently to least-frequently contacted within a given window of observation. Tracking high school graduates transitioning into university using mobile call detail records, Saramäki and colleagues established two defining regularities: first, social signatures vary substantially across individuals; and second, an individual's social signature exhibits remarkable intra-individual persistence over time, remaining stable even when the specific alters occupying the network turn over substantially. Subsequent investigations demonstrated that persistent signature patterns generalize across multiple communication channels, including voice calls and text messaging (Heydari et al. 2018; Kikas et al. 2013).

Despite these important empirical breakthroughs, significant theoretical and empirical gaps remain in our understanding of personal communication architectures. First, existing studies have relied primarily on call logs from commercial telecommunications providers. Because commercial telecommunications data lack relational content, researchers have been unable to determine whether the steep mathematical drop-off in communication frequency corresponds to qualitative differences in social support—such as emotional comfort, instrumental advice, companionship, or financial assistance. Second, the behavioral mechanisms underlying signature persistence remain ambiguous: does an individual's signature remain stable because their core ties are immutable, or do individuals actively preserve their structural signature by "slotting" newly acquired alters into vacant relational positions? Third, prior research has largely neglected the psychological dispositions and well-being correlates that give rise to distinct signature shapes. Why do some individuals maintain steep, hyper-concentrated communication profiles focused on a single alter, while others sustain broad, egalitarian distributions of attention?

This paper addresses these foundational questions by drawing on the **NetHealth Project**—a comprehensive, multi-year cohort study tracking undergraduate students at the University of Notre Dame. By integrating two full years of continuous, passive smartphone communication logs (498,237 outgoing voice call records) with dense 8-wave ego-network surveys, alter-alter structural edge lists, and longitudinal psychometric batteries, we examine the persistence, mathematical form, social support grounding, and psychological origins of social signatures during a major life-course transition.

---

## 2. Data and Methodology

### 2.1 The NetHealth Dataset
The NetHealth study recruited an entire incoming cohort of first-year undergraduate students at the University of Notre Dame beginning in Fall 2015 (comprehensive documentation and study protocols are available at the project website: https://sites.nd.edu/nethealth/). Participants consented to continuous digital sensing via their smartphones and Fitbit devices, alongside dense ego-network and psychological surveys administered at regular intervals across their college careers. 

Our analytical design links five primary data streams:
1. **Continuous Communication Logs**: 498,237 outgoing voice call events collected from participant iOS devices spanning June 30, 2015 through July 2, 2017 across 491 unique egos.
2. **Academic Calendar**: Comprehensive institutional records documenting semester start and end dates, examination periods, orientation, and vacation breaks.
3. **Ego-Network Surveys**: 35,913 alter nominations gathered across 8 longitudinal survey waves recording tie categories (family kin vs. peer friends), perceived closeness, interpersonal trust, and multidimensional social support.
4. **Alter-Alter Edge Lists**: 174,748 structural ties connecting peers within each respondent's personal egocentric network across survey waves.
5. **Basic Psychometric Batteries**: Longitudinal survey instruments measuring the Big Five personality dimensions (Extraversion, Agreeableness, Conscientiousness, Negative Emotionality [historically termed Neuroticism], Openness).

### 2.2 Temporal Window Binning and Filtering
To establish whether social signatures persist across differing temporal resolutions, we construct two complementary binning architectures:
- **Calendar-Based Windows** (July 1, 2015 – June 30, 2017):
  - *Academic Years* (*W* = 2): July 2015 – June 2016; July 2016 – June 2017.
  - *Semesters* (*W* = 4): Fall 2015, Spring 2016, Fall 2016, Spring 2017.
  - *Quarters* (*W* = 8): July–September, October–December, January–March, April–June.
  - *Months* (*W* = 24): 24 consecutive calendar months.
- **Week-Based Windows** (July 6, 2015 – July 2, 2017; 104 Monday–Sunday weeks):
  - *3-Week Rolling Windows* (*W* = 102): 3-week moving windows in 1-week increments.
  - *2-Week Discrete Windows* (*W* = 52): Non-overlapping 14-day intervals.
  - *1-Week Discrete Windows* (*W* = 104): 7-day intervals.

To ensure that estimated signatures reflect meaningful personal communication structures, egos are required to meet two standard inclusion criteria: (a) a minimum of 2 active alters in every window (*k* >= 2), and (b) an average call volume exceeding 10 calls per window. While the overarching sensing pool comprises *N* = 491 unique egos with outgoing calls, the number of eligible participants varies across timescales based on continuous observation requirements: Academic Years (*N* = 388), Semesters (*N* = 290), Quarters (*N* = 227), Months (*N* = 147), and Rolling Weekly Windows (*N* = 88). The collegiate semester timescale (*N* = 290 egos) serves as our primary analytical cohort for subsequent dyadic, panel, and personality modeling. When directly comparing across calendar resolutions, we evaluate the common calendar cohort (*N* = 147 egos) present in all four schemes simultaneously.

{{TABLE_1}}
**Table 1.** NetHealth Cohort Summary Across Temporal Window Definitions

### 2.3 Mathematical Formulation of Social Signatures and Jensen-Shannon Divergence
For ego *i* in temporal window *w*, communication weights *w~ij,w~* (measured as total outgoing voice calls) to alters *j* = 1, ..., *k~i,w~* are ordered in descending rank: *w~(1)~* >= *w~(2)~* >= ... >= *w~(k)~*. The social signature is defined as the normalized vector of interaction proportions:
*p~i,w~*(*r*) = *w~ij(r),w~* / *W~i,w~*, where *W~i,w~* = ∑ *w~ij,w~* and ∑ *p~i,w~*(*r*) = 1

To quantify the similarity or difference between two signatures *P* = {*p~r~*} and *Q* = {*q~r~*} of lengths *k*~1~ and *k*~2~, we append zeros to the shorter distribution up to length max(*k*~1~, *k*~2~) and compute the **Jensen-Shannon Divergence (JSD)** (Lin 1991):
JSD(*P* || *Q*) = *H*(*M*) - 0.5 · [*H*(*P*) + *H*(*Q*)]
where *M* = 0.5 · (*P* + *Q*), and *H*(*P*) = -∑ *p~r~* log~2~(*p~r~*) is Shannon entropy in bits.

We specify two core divergence metrics:
- **Self-Divergence (*d*~self~)**: The mean pairwise JSD between consecutive temporal windows for the same ego across observation periods:
  *d*~self~(*i*) = [1 / (*W* - 1)] ∑ JSD(*P~i,w~* || *P~i,w+1~*)
- **Reference-Divergence (*d*~ref~)**: The divergence between the social signatures of distinct individuals observed within the same temporal window:
  - *By ego, averaged within windows*: For ego *i*, the mean divergence to all other (*n* - 1) egos within window *w*, averaged across windows.
  - *All pairs, averaged over windows*: The mean divergence across all pairs of distinct individuals across all windows.

If personal social signatures exhibit persistence over time, an individual's self-divergence must be systematically and significantly lower than the reference divergence between different individuals (*d*~self~ < *d*~ref~).

---

## 3. Empirical Results: Persistence and Parametric Architecture

### 3.1 Empirical Social Signatures
Figure 1 displays the empirical social signatures averaged across egos for ranks 1 through 15 across temporal window definitions. Across all timescales, communication effort exhibits heavy skewness:
- The single top-ranked alter (*r* = 1) commands **35% to 45%** of an ego's total communication effort.
- The second-ranked alter (*r* = 2) captures **18% to 22%**.
- The top 3 alters collectively account for over **70%** of an ego's total interaction bandwidth.
- Beyond rank 5, communication drops below 4% per alter.

{{FIGURE_1}}
**Figure 1.** Empirical Social Signatures across Temporal Window Resolutions (Ranks 1–15)

### 3.2 Robust Intra-Individual Persistence (Self vs. Reference Divergence)
Table 2 reports the formal statistical comparison between intra-individual self-divergence (*d*~self~) and inter-individual reference divergence (*d*~ref~).

{{TABLE_2}}
**Table 2.** Statistical Tests of Social Signature Persistence

Across every temporal resolution examined, intra-individual self-divergence is significantly lower than inter-individual reference divergence (*p* < 0.0001, Wilcoxon signed-rank test). In the semester window definition, mean self-divergence is 0.0614, compared to a reference divergence of 0.1184 (*V* = 1136, *p* < 0.0001). Even at fine-grained weekly scales (3-week rolling windows), an individual's signature remains exceptionally consistent across time (*d*~self~ = 0.0495) relative to the broader population (*d*~ref~ = 0.1411, *p* < 0.0001). As shown in Figure 2, the distributions of self and reference divergence exhibit minimal overlap, confirming that personal communication signatures reflect enduring individual attributes.

{{FIGURE_2}}
**Figure 2.** Persistence of Social Signatures: Self vs. Reference Divergence

### 3.3 Parametric Form: Power-Law vs. Exponential Decay
We evaluated two competing functional specifications for the signature curve:
1. **Power-Law Specification**: *p*(*r*) = *c* · *r*^-*α*^, or log *p*(*r*) = log *c* - *α* log *r*
2. **Exponential Specification**: *p*(*r*) = *c* · *e*^-*βr*^, or log *p*(*r*) = log *c* - *βr*

{{TABLE_3}}
**Table 3.** Parametric Model Evaluation Across Window Resolutions

As summarized in Table 3 and Figure 3, the power-law model decisively outperforms the exponential specification across both semester and monthly timescales. In semester windows, the power-law specification is preferred by Akaike Information Criterion (AIC) in **97.0% of models**, yielding an average *R*^2^ of 0.935 (compared to 0.746 for exponential decay). The power-law decay exponent *α* averages 1.22 (SD = 0.25), reflecting a heavy-tailed allocation profile.

{{FIGURE_3}}
**Figure 3.** Power-Law vs Exponential Model Fits and Exponent Distribution

### 3.4 Longitudinal Parameter Convergence and Burn-In
To establish how long an individual must be observed before their estimated signature parameters stabilize, we tracked the common cohort across cumulative observation lengths from 2 to 24 months (Figure 4).
- At 2 months: Mean *α* = 1.16, with a mean absolute error of 0.188 relative to the 24-month asymptotic value.
- At 4 months: Mean absolute error declines to 0.141 (*R*^2^ = 0.934).
- At 6 to 8 months: Mean absolute error converges below 0.10 (*R*^2^ = 0.945).

These findings indicate that **6 months of continuous digital observation** provides an optimal burn-in threshold for reliably characterizing personal social signatures in young adult populations.

{{FIGURE_4}}
**Figure 4.** Parameter Burn-In Convergence Over 24 Months

---

## 4. Theoretical Expansions

### 4.1 Grounding Communication Ranks in Dimensions of Social Support
While prior literature has treated communication ranks as purely behavioral tallies, we linked the call records of the collegiate semester cohort (*N* = 290 egos) to the longitudinal network surveys. This matched *N* = 13,174 call-ranked dyadic observations across 283 unique egos (7 egos nominated no active alters in the survey) to relationship categories and support functions across six theoretical Dunbar tiers:

{{TABLE_4}}
**Table 4.** Relational Composition and Support Functions Across Signature Rank Tiers

The findings (Table 4, Figure 5) illuminate the qualitative architecture underlying social signatures:
1. **The Kinship Core**: Rank 1 is heavily dominated by family members (69.7% kin, primarily parents and romantic partners), who provide the structural foundation of instrumental, advice, and financial support (64.1% financial assistance, 87.6% advice, 85.4% emotional support).
2. **The Friendship Transition**: A sharp structural crossover occurs between Ranks 3 and 5. At Ranks 2–3, family members still constitute 62.2% of ties; by Ranks 4–5, peer friends constitute the majority (56.9%), rising to 87.8% beyond Rank 20.
3. **Differentiated Support Gradient**: Emotional support (85.4% at Rank 1) and advice support (87.6% at Rank 1) fall monotonically across tiers (dropping to 39.1% and 44.0% for outer ties). In sharp contrast, companionship remains elevated across all tiers (80.6% at Rank 1, 81.9% at Ranks 4–5, and 69.4% beyond Rank 20), demonstrating that peripheral communication ties serve primary social leisure and recreational functions.

{{FIGURE_5}}
**Figure 5.** Dimensions of Social Support Across Signature Rank Tiers

### 4.2 Evaluative and Cognitive Alignment: Closeness, Duration, and Salience
Beyond discrete provisions of social support, an alter's position slot in the social signature is strongly and systematically correlated with the primary evaluative and cognitive dimensions recorded in the network survey (Figure 5B, Table 4B):
- **Subjective Closeness**: 93.7% of Rank 1 alters are rated "especially close" (mean 3.93 on a 1–4 scale), tapering steadily to 52.7% for alters at Ranks >20 (*r* = -0.222, *p* < 0.0001; with call proportion *r* = +0.238).
- **Relationship Duration**: Rank 1 alters average 14.2 years of relationship history (median 18.8 years), capturing lifelong family and childhood confidants, compared to 4.9 years (median 2.1 years) for outer-tier contacts formed during college (*r* = -0.266, *p* < 0.0001; with call proportion *r* = +0.333).
- **Cognitive Recall Salience**: Over one-third (36.4%) of Rank 1 alters are recalled and named first in the survey (71.2% in the top 5), whereas outer-tier alters average a recall position of 9.9 (*r* = +0.243, *p* < 0.0001; with call proportion *r* = +0.282).

{{FIGURE_5B}}
**Figure 5B.** Evaluative and Cognitive Alignment Across Social Signature Rank Tiers

To test whether these dimensions independently predict signature placement while accounting for the nesting of alters within egos ($J = 280$ individuals, averaging 38.7 ties per ego), Table 4B reports linear mixed-effects models with ego random intercepts. In the baseline model, the ego-level intraclass correlation (ICC) is 0.109. Adding tie duration in Model 2 confirms that relationship longevity exerts a powerful independent effect on communication allocation ($t = 27.95, p < 0.0001$). Incorporating cognitive salience in Model 3 demonstrates that recall order further drives calling proportion ($t = 23.47, p < 0.0001$), with tie duration ($t = 30.26$), subjective closeness ($t = 4.73$), and interpersonal trust ($t = 6.95$) each maintaining highly significant positive effects. Finally, Model 4 confirms that these dimensions jointly predict an alter's ordinal signature rank ($p < 0.0001$), with greater closeness, longevity, and recall salience pulling alters closer to the Rank 1 core.

{{TABLE_4B}}
**Table 4B.** Linear Mixed-Effects Models Predicting Signature Allocation and Rank from Tie Attributes

### 4.3 The "Slot-Filling" Dynamic: Alter Turnover vs. Signature Stability
A central theoretical puzzle in network science is how an ego's signature can remain stable despite frequent alter replacement. We calculated the dyadic Jaccard turnover (1 - *J*) between consecutive semesters.

Remarkably, **alter turnover between consecutive semesters averages 80.1% (SD = 0.076)**. Despite replacing four out of five alters every six months, egos maintain an average self-divergence of only 0.0614. In 59.1% of consecutive semester intervals, the single top-ranked alter was retained; even when the top alter was replaced, the overall self-divergence increased only modestly (from 0.0431 to 0.0785, Figure 6). 

This pattern provides direct empirical confirmation of the **slot-filling hypothesis**: an individual maintains a predefined cognitive template for relationship allocation, seamlessly slotting new social entrants into vacant relational positions without perturbing their structural allocation curve.

{{FIGURE_6}}
**Figure 6.** The 'Slot-Filling' Dynamic: Alter Turnover vs. Signature Divergence (*r* = 0.456, *p* < 0.0001)

### 4.4 Multilevel Panel Models of Signature Divergence
To identify the structural and psychological drivers of signature mutation over time, we estimated linear mixed-effects panel models with ego random intercepts:
Self-JSD~*it*~ = *β*~0~ + *β*~1~ Turnover~*it*~ + *β*~2~ ΔActivity~*it*~ + **X**~*it*~ **γ** + *u~i~* + *ε~it~*

{{TABLE_5}}
**Table 5.** Multilevel Linear Mixed-Effects Models Predicting Signature Self-Divergence

As reported in Table 5, alter turnover is the primary driver of signature divergence (*β* = 0.351, *p* < 0.0001), followed by large shifts in communication volume (*β* = 0.0014, *p* < 0.0001). Net of turnover, ego network clustering does not significantly alter signature stability, underscoring that signatures reflect cognitive rather than purely topological constraints.

### 4.5 Personality Determinants of Signature Shape
What psychological dispositions generate steep (core-concentrated) versus flat (diffuse) social signatures? Regressing ego-mean power-law decay exponents (*α~i~*) on Big Five personality traits and personal network degree (Table 6, Figure 7) reveals:

{{TABLE_6}}
**Table 6.** Personality Determinants of Social Signature Power-Law Alpha

**Negative Emotionality is a highly significant, positive predictor of signature steepness (*β* = 0.098, *t* = 5.08, *p* < 0.0001)**. Individuals high in negative emotionality exhibit hyper-concentrated communication profiles, funneling the vast majority of their interactions into one or two primary alters while under-investing in intermediate and outer bands. Agreeableness also exhibits a modest positive association with concentration (*β* = 0.063, *p* = 0.014). In contrast, extraversion tends to flatten signatures toward broader alter engagement.

{{FIGURE_7}}
**Figure 7.** Personality Predictors of Social Signature Alpha

### 4.6 Non-Linear Thresholds and Moderation: CART Regression Tree
While linear regression tests parametric main effects, it assumes strictly additive relationships. To uncover non-linear thresholds and psychological trait interactions, we trained a Classification and Regression Tree (CART; Breiman et al. 1984) predicting mean power-law decay exponents (*α~i~*) from baseline Big Five traits (Figure 7B):
- **Relative Variable Importance**: Negative Emotionality dominates the tree architecture (49%), followed by Extraversion (19%), Openness (16%), Agreeableness (13%), and Conscientiousness (2%).
- **Primary Root Split (Negative Emotionality < 2.44)**: Individuals in the lowest third of Negative Emotionality form an immediate terminal leaf characterized by flat, egalitarian signatures (mean *α* = 1.121).
- **Extraversion as a Conditional Buffer**: For individuals with elevated Negative Emotionality (>= 2.44), the tree branches conditionally on Extraversion (< 2.56 vs. >= 2.56). Introverted individuals with high Negative Emotionality exhibit extreme relational concentration (mean *α* = 1.322), rising to *α* = 1.392 when Agreeableness is high. Conversely, moderate-to-high Extraversion buffers against hyper-concentration (mean *α* = 1.223), explaining why Extraversion showed no linear main effect in OLS regression.

{{FIGURE_7B}}
**Figure 7B.** CART Decision Tree Predicting Social Signature Alpha from Big Five Traits

---

## 5. Discussion and Conclusion

By linking continuous passive smartphone logs with multi-wave ego-network surveys and psychological batteries in the NetHealth cohort, this study provides empirical backing for social signature theory while advancing the paradigm into sociological and psychological domains.

Our key findings span four fundamental domains:
1. **Unambiguous Persistence**: Social signatures in NetHealth are persistent across timescales ranging from 3-week rolling windows to multi-year academic terms. An individual's signature divergence across time is less than half the divergence observed between random peers.
2. **Substantive Grounding in Social Support**: Social signature ranks are not arbitrary artifacts of call logging; they map directly to evolutionary Dunbar tiers. Rank 1 represents a specialized kin-based support hub, Ranks 2–5 represent the core emotional confidant circle, and ranks beyond 5 represent peer-based companionship.
3. **Evaluative and Cognitive Alignment**: Position slots in the social signature strongly align with subjective closeness (*p* < 0.0001), relationship duration (*p* < 0.0001), and top-of-mind cognitive recall salience (*p* < 0.0001). In linear mixed-effects models accounting for clustering within egos, relationship longevity and recall salience remain powerful independent predictors of communication investment.
4. **The Psychological Signature and Conditional Moderation**: The shape of the social signature is anchored in personality dispositions. Negative Emotionality drives individuals to adopt steep, core-concentrated allocation strategies (*β* = 0.098, *p* < 0.0001). Decision-tree modeling (CART) reveals that Extraversion acts as a protective moderator: among emotionally reactive individuals, introversion accelerates retreat into an exclusive relational dyad, while extraversion preserves broader social connectivity.

Future research should leverage high-resolution wearable sensing (Fitbit physical activity, sleep regularity, and colocation traces) to examine whether disruptions in social signature equilibrium serve as early-warning biomarkers for academic distress and psychological strain during major life transitions.

---

## References

- Centellegher, Simone, et al. 2017. "Personality Traits and Ego-Network Dynamics." *PLOS ONE* 12(3): e0173110.
- Chandler, Matthew J. 2019. "Patterns in Social Signatures." Presentation, Interdisciplinary Center for Network Science & Applications (iCeNSA), NetHealth Project, University of Notre Dame.
- Dunbar, Robin I.M. 1992. "Neocortex Size as a Constraint on Group Size in Primates." *Journal of Human Evolution* 22(6): 469–493.
- Dunbar, Robin I.M. 2018. "The Anatomy of Friendship." *Trends in Cognitive Sciences* 22(1): 32–51.
- Heydari, Somayeh, et al. 2018. "Multichannel Social Signatures and Persistent Features of Ego Networks." *Applied Network Science* 3(8): 1–19.
- Kikas, Riivo, et al. 2013. "Burstiness and Asymmetry in Mobile Communication Networks." *Social Networks* 35(4): 543–552.
- Lin, Jianhua. 1991. "Divergence Measures Based on the Shannon Entropy." *IEEE Transactions on Information Theory* 37(1): 145–151.
- Miritello, Giovanna, et al. 2013. "Time as a Limited Resource: Communication Strategy in Mobile Phone Networks." *Social Networks* 35(1): 89–95.
- Roberts, Sam G.B., et al. 2009. "Exploring Variation in Active Network Size: Constraints and Predictors." *Social Networks* 31(2): 138–146.
- Saramäki, Jari, et al. 2014. "Persistence of Social Signatures in Human Communication." *Proceedings of the National Academy of Sciences* 111(3): 942–947.
- Sutcliffe, Alistair, et al. 2012. "Relationships and the Social Brain: Integrating Psychological and Evolutionary Perspectives." *British Journal of Psychology* 103(2): 149–168.
