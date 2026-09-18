__attribute__((target_clones("cpu=power8,default")))
int callee(int x) {
    return x * 2;
}

__attribute__((target("cpu=power8")))
int caller(int x) {
    return callee(x) + 1;
}
