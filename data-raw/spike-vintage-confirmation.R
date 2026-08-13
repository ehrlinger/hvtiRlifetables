## Spike part 4: which uslife vintage produced this study's uslife.sas7bdat?
## %usmatchd = PROC HAZPRED on a stored 3-phase model (INHAZ=USLIFExx.HZIC**),
## evaluated on the AGE axis (time origin = birth):
##   h(a) = muE*g(a) + muC + muL*g3'(a)      H(a) = muE*G(a) + muC*a + muL*G3(a)
##   AGESURV = exp(-H(age));  SMATCHED(t) = exp(-H(age+t))/AGESURV
suppressMessages(library(haven)); suppressMessages(library(TemporalHazard))

VINT <- c(table84 = "table84", table2008 = "table2008", table2023 = "table2023")
STRATA <- c(wm = "hzicwm", wf = "hzicwf")          # white male / white female
OTH84  <- c(om = "hzicom", of = "hzicof")          # 1984 names "other"
OTH08  <- c(om = "hzicbm", of = "hzicbf")          # 2008/2023 name it "B"

parms <- function(v, f) {
  p <- as.data.frame(read_sas(sprintf(
    "/Volumes/qhsstudies/general/uslife/%s/estimates/%s.sas7bdat", v, f)))
  list(est = setNames(as.numeric(p[["_EST_"]]), p[["_NAME_"]]), st = setNames(p[["_STATUS_"]], p[["_NAME_"]]))
}

## mu is present only when its _STATUS_ is 1; _STATUS_ 0 means the phase is
## absent from the model, NOT log-mu = 0 (which would be a hazard of 1/yr).
mu <- function(p, nm) if (isTRUE(p$st[[nm]] == 1)) exp(p$est[[nm]]) else 0

## cumulative hazard / hazard on the age axis (time origin = birth)
cumhaz <- function(p, a) {
  e <- p$est
  g3 <- hzr_decompos_g3(a, tau = e[["TAU"]], gamma = e[["GAMMA"]],
                        alpha = e[["ALPHA"]], eta = e[["ETA"]])
  mu(p, "E0") * hzr_phase_cumhaz(a, t_half = e[["THALF"]], nu = e[["NU"]],
                                 m = e[["M"]], type = "cdf") +
  mu(p, "C0") * a +
  mu(p, "L0") * g3$G3
}
hazrate <- function(p, a) {
  e <- p$est
  g3 <- hzr_decompos_g3(a, tau = e[["TAU"]], gamma = e[["GAMMA"]],
                        alpha = e[["ALPHA"]], eta = e[["ETA"]])
  mu(p, "E0") * hzr_phase_hazard(a, t_half = e[["THALF"]], nu = e[["NU"]],
                                 m = e[["M"]], type = "cdf") +
  mu(p, "C0") +
  mu(p, "L0") * g3$g3
}

u <- as.data.frame(read_sas("estimates/uslife.sas7bdat")); u <- u[order(u$CCFID, u$TIME), ]
pt <- unique(u[, c("CCFID","AGE","MALE","OTHER","AGESURV")])
for (v in c("AGE","MALE","OTHER","AGESURV")) pt[[v]] <- as.numeric(pt[[v]])
tg <- as.numeric(sort(unique(u$TIME)))
sasS <- matrix(u$SMATCHED, nrow = nrow(pt), byrow = TRUE)
sasH <- matrix(u$HMATCHED, nrow = nrow(pt), byrow = TRUE)

grp <- with(pt, ifelse(MALE == 1 & OTHER == 0, "wm",
              ifelse(MALE == 0 & OTHER == 0, "wf",
              ifelse(MALE == 1, "om", "of"))))
cat("stratum n:", paste(names(table(grp)), table(grp), collapse="  "), "\n\n")

for (v in VINT) {
  files <- c(STRATA, if (v == "table84") OTH84 else OTH08)
  P <- lapply(files, parms, v = v)
  ag  <- vapply(seq_len(nrow(pt)), function(i) {
           p <- P[[grp[i]]]; exp(-cumhaz(p, pt$AGE[i])) }, numeric(1))
  H0  <- vapply(seq_len(nrow(pt)), function(i) hazrate(P[[grp[i]]], pt$AGE[i]), numeric(1))
  S10 <- vapply(seq_len(nrow(pt)), function(i) {
           p <- P[[grp[i]]]
           exp(-(cumhaz(p, pt$AGE[i] + 10) - cumhaz(p, pt$AGE[i]))) }, numeric(1))
  cat(sprintf("%-10s AGESURV max|d| %.3e | HMATCHED(t=0) max|d| %.3e | SMATCHED(10yr) max|d| %.3e\n",
      v, max(abs(ag - pt$AGESURV)), max(abs(H0 - sasH[, 1])), max(abs(S10 - sasS[, 151]))))
}

## Full-curve check at the winning vintage
cat("\n--- full 151-point curve, table84 ---\n")
P <- lapply(c(STRATA, OTH84), parms, v = "table84")
S <- t(vapply(seq_len(nrow(pt)), function(i) {
  p <- P[[grp[i]]]
  exp(-(cumhaz(p, pt$AGE[i] + tg) - cumhaz(p, pt$AGE[i]))) }, numeric(151)))
H <- t(vapply(seq_len(nrow(pt)), function(i)
  hazrate(P[[grp[i]]], pt$AGE[i] + tg), numeric(151)))
cat("SMATCHED: max|d|", max(abs(S - sasS)), " mean|d|", mean(abs(S - sasS)), "\n")
cat("HMATCHED: max|d|", max(abs(H - sasH)), " mean|d|", mean(abs(H - sasH)), "\n")
cat("mean curve @10yr: R", mean(S[,151]), " SAS", mean(sasS[,151]),
    " diff", mean(S[,151]) - mean(sasS[,151]), "\n")
cat("\nworst patient:\n"); w <- which.max(abs(S - sasS)) %% nrow(pt)
print(pt[w, ]); cat("max row err:", max(abs(S[w,] - sasS[w,])), "\n")
