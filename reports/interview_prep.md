# Interview Prep

Short answers built from this project's actual results. Say them in your own words; the goal is to understand, not memorize.

## The six core questions

**1. Why a two-proportion z-test, and what does it assume?**
Conversion is yes/no, so each group's conversion count is binomial, and I'm comparing two proportions. With 420 PSA conversions and 14,423 ad conversions, the normal approximation is very accurate. It assumes random assignment, independent users, and one row per user; I confirmed there are no duplicate users.

**2. What does the confidence interval mean in plain English?**
The 95% CI for the relative lift is 30% to 58%. If we repeated the experiment many times, 95% of intervals built this way would contain the true lift. Practically, lifts in that range are consistent with the data, and "no effect" is not.

**3. Why is the split lopsided, and does it matter?**
Only 4% of users were in the control. The intended ratio isn't documented, so I can't run a sample ratio mismatch test or say whether it was deliberate; a small holdout is common to limit lost revenue. It matters for precision: the small group dominates the standard error, so the test has about the precision of a balanced test with 45K per arm, not 588K.

**4. Statistical vs practical significance here?**
Statistically, the p-value is 8.5 × 10⁻¹⁴ and the lift is 3.4× the smallest effect the design could reliably detect. Practically, whether a 0.77 pp lift is *worth it* depends on media cost and conversion value, which aren't in the data. So I computed break-even: at an assumed $5 CPM, a conversion must be worth about $16.

**5. Why is the segment analysis only exploratory?**
The segment variables (ads seen, busiest day and hour) were measured after assignment, and exposure wasn't randomized. Heavy viewers may just be more active users. I also ran 15 tests, so I used Holm correction and fixed the segments before looking at their results.

**6. What would you do in a follow-up test?**
Document the intended split and run an SRM check, log timestamps, fix the duration in advance (at least two weeks), add guardrail metrics like unsubscribes, and randomize ad frequency. The frequency arm answers the question this data can't: do more ads cause more conversions?

## Likely follow-ups

**Why pooled SE for the test but unpooled for the CI?**
Under H0 both groups share one rate, so pooling estimates it best for the test. The CI describes the difference we observed, so each group uses its own variance.

**Your Python and R intervals: did they match immediately?**
Only once I set `method="wald"` in statsmodels (its default is Newcombe) and used a two-sided `prop.test` for the interval (a one-sided call returns a one-sided interval). Then z, p and CI matched to many decimals, and my SQL version matched too.

**Is your bootstrap parametric?**
It draws from Binomial(n, p̂). For 0/1 data that's exactly what resampling users with replacement produces, so it's the ordinary bootstrap computed faster. It agreed with the z-test interval (0.60 to 0.94 pp both ways).

**The groups had different exposure patterns. Does that break the test?**
No. Assignment still determined which creative each user saw. The differences were tiny in effect size (at most 0.04). As a sensitivity check, a logistic model adjusting for exposure gave +0.76 pp vs +0.77 pp unadjusted. I kept the unadjusted estimate as the headline because adjusting for post-treatment variables can introduce bias.

**Why Holm and not Bonferroni?**
Both control the chance of any false positive, but Holm rejects at least as many true effects. It's a free improvement.

**What's the most interesting thing you found?**
Two thirds of users saw 20 or fewer ads, and for them there's no detectable lift. The whole effect sits with heavily exposed users. That changes the next question from "should we run ads?" to "how often should each user see them?", which needs a randomized frequency test.

**What would you do differently with more data?**
Use pre-experiment user attributes for a balance check and variance reduction (such as CUPED), and timestamps to check novelty effects and whether the lift decays.
