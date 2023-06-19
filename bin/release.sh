export VERSION=$1
echo "VERSION: ${VERSION}"

echo "=== Pushing tags to github ===="
git tag v"$VERSION"
git push origin --tags

echo "=== Building Gem ===="
gem build pg_easy_replicate.gemspec

echo "=== Pushing gem ===="
gem push pg_easy_replicate-"$VERSION".gem

echo "=== Sleeping for 5s ===="
sleep 5

echo "=== Building Image ===="
docker build . --build-arg VERSION="$VERSION" -t shayonj/pg_easy_replicate:"$VERSION"

echo "=== Tagging Image ===="
docker image tag shayonj/pg_easy_replicate:"$VERSION" shayonj/pg_easy_replicate:latest

echo "=== Pushing Image ===="
docker push shayonj/pg_easy_replicate:"$VERSION"
docker push shayonj/pg_easy_replicate:latest

echo "=== Cleaning up ===="
rm pg_easy_replicate-"$VERSION".gem
