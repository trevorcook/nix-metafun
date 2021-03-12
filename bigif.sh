

if (
  if true; then
    echo "true"
  fi
  false) ; then
  echo pass
else
  echo fail
fi
