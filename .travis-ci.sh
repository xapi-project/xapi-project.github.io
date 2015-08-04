TEST_BASEURL="baseurl_travis_test"

echo "Running jekyll's sanity test..."
bundle exec jekyll doctor

echo "Building site (with modified baseurl)..."
cp _config.yml test_config.yml
echo "baseurl: /${TEST_BASEURL}" >> test_config.yml
bundle exec jekyll build --config test_config.yml
rm test_config.yml

echo "Running htmlproof over generated site..."
mv _site ${TEST_BASEURL}
mkdir _site
mv ${TEST_BASEURL} _site
export NOKOGIRI_USE_SYSTEM_LIBRARIES=true  # speeds up install of html-proofer
bundle exec htmlproof --check-html ./_site
