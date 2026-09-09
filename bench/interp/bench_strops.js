const line = "alpha,beta,gamma,delta,epsilon,zeta,eta,theta";
const n = 120000;
const t0 = Date.now();
let total = 0;
for (let i = 0; i < n; i++) {
    const parts = line.split(",");
    total += parts.length;
    if (line.indexOf("delta") >= 0) total += 1;
    const joined = parts.join("|");
    total += joined.length;
}
console.log("result: " + total);
console.log("elapsed: " + (Date.now() - t0) + " ms");
