function getcfg { $cssb/bin/opt -passes=dot-cfg-only -cfg-func-name=main $1 -o /dev/null; }
function cutfunc0 { cat $1 | sed -n "/define .*(/,/^}/p"; }
function cutfunc {
    if [ "$#" -ne 2 ]; then
        echo "Usage: $0 <input.ll> <function_name>";
        return 1;
    fi;
    INPUT_FILE="$1";
    FUNC_NAME="$2";
    sed -n "/define .*@${FUNC_NAME}(/,/^}/p" "$INPUT_FILE"
}

