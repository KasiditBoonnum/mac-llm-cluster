#!/usr/bin/env python3
"""Discord Bot for LLM Cluster"""

import discord
from discord.ext import commands
import requests
import os

DISCORD_TOKEN = os.getenv("DISCORD_BOT_TOKEN")
GATEWAY_URL = "https://llm-01.local:8443"
API_KEY = os.getenv("LLM_API_KEY")

intents = discord.Intents.default()
intents.message_content = True
bot = commands.Bot(command_prefix='!llm ', intents=intents)


@bot.command(name='ask')
async def ask(ctx, *, question: str):
    """Ask the cluster a question"""
    thinking = await ctx.send("🤔 Processing...")
    try:
        response = requests.post(
            f"{GATEWAY_URL}/v1/chat/completions",
            headers={"Authorization": f"Bearer {API_KEY}"},
            json={"model": "qwen2.5:32b", "messages": [{"role": "user", "content": question}]},
            verify=False, timeout=60
        )
        if response.status_code == 200:
            data = response.json()
            answer = data.get("response", "No response")
            await thinking.edit(content=answer[:2000])
    except Exception as e:
        await thinking.edit(content=f"❌ Error: {str(e)}")


@bot.command(name='status')
async def status(ctx):
    """Check cluster status"""
    try:
        resp = requests.get("http://llm-01.local:8080/queue/status", timeout=5)
        if resp.status_code == 200:
            d = resp.json()
            msg = (f"✅ **Cluster Online**\n"
                   f"Mode: {d['mode']} | Queue: {d['queue_length']} | "
                   f"Node3: {d['node3_model']} | Exo: {'ON' if d['exo_loaded'] else 'OFF'}")
            await ctx.send(msg)
        else:
            await ctx.send(f"⚠️ Status: {resp.status_code}")
    except Exception:
        await ctx.send("❌ Cluster: Offline")


@bot.command(name='models')
async def models(ctx):
    """List available models"""
    msg = ("**Available Models:**\n"
           "• `phi4:14b` - Node 1, fast general use\n"
           "• `qwen2.5:32b` - Node 2, powerful reasoning\n"
           "• `deepseek-coder-v2:33b` - Node 3, code tasks\n"
           "• `exo:qwen3-30b` - All 3 nodes, 64K context")
    await ctx.send(msg)


if __name__ == "__main__":
    if not DISCORD_TOKEN:
        print("❌ Set DISCORD_BOT_TOKEN environment variable")
        exit(1)
    bot.run(DISCORD_TOKEN)
