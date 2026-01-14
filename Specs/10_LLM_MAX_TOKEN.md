# LLM Max Token

We have the option to limit the max token in the LLM Profile. But that seems not enough. Therefore we should

- Understand what different token limits there are. Pls explain clearly and easily (almost eli5 ;) )
- Get model token limits from models.dev/api.json This page is maintained, we should reload it once a day at app startup and save it locally. We then take the per model limits from there to guide the user on what he can configure in the LLM profile.
- The UI should ensure that it's difficult (but possible!) for the user to set max token above the suggested limits
- The user should clearly understand how messages are ensured to stay within the limits (i.e. what is truncated).