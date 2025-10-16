# Run Locally

If you want to just test the app:

```sh
cd apps/ai-chatbot

export GEMINI_API_KEY="your_gemini_api_key"
export PRISMA_AIRS_API_KEY="your_prisma_airs_api_key"
export PRISMA_AIRS_PROFILE="your_prisma_airs_profile"

docker build -t gemini-chatbot .
docker run -p 5000:5000 \
  -e GEMINI_API_KEY=$GEMINI_API_KEY \
  -e PRISMA_AIRS_API_KEY=$PRISMA_AIRS_API_KEY \
  -e PRISMA_AIRS_PROFILE=$PRISMA_AIRS_PROFILE \
  gemini-chatbot
```

Once the container is running, open your browser and go to `http://localhost:5000/ai-chatbot`.