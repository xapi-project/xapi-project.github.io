TEST_BASEURL="baseurl_travis_test"

cp _config.yml test_config.yml
echo "url: http://example.com/${TEST_BASEURL}" >> test_config.yml

echo "Running jekyll's sanity test...(with modified url)"
bundle exec jekyll doctor --config test_config.yml

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
bundle exec htmlproofer --check-html ./_site
