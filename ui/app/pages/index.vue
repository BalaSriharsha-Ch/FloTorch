<script setup lang="ts">
definePageMeta({
  layout: false,
});

useHead({
  title: "FloTorch",
});
</script>

<template>
  <div class="flex flex-col min-h-screen bg-white w-full">
    <header class="navbar text-white p-2 w-full">
     <div class="mx-10 pb-12  flex flex-col">
        <div class="w-full flex justify-between">
          <NuxtLink :to="{ name: 'index' }" class="self-center cursor-default">
            <img src="/logo.png" alt="logo" class="w-[200px]" />
          </NuxtLink>
          <UButton
           class="height-[32px] github-link self-center"
            icon="i-lucide-github"
            variant="outline"
            color="neutral"
            href="https://github.com/FissionAI/FloTorch"
            target="_blank"
          />
        </div>
      </div>
    </header>
    <main
      class="flex-1 container mx-auto flex flex-col items-center justify-center gap-4"
    >
      <h1 class="text-4xl font-bold">FloTorch</h1>
      <p class="text-lg">
        Manage and run your GenAI experiments at scale with ease
      </p>
      <img src="/flotorch-hero.gif" alt="hero" class="w-full max-w-7xl" />
      <UButton
        class="primary-btn"
        label="Get Started"
        trailing-icon="i-lucide-arrow-right"
        :to="{ name: 'projects' }"
        size="xl"
      />
    </main>
    <div class="footer-container mt-[50px]">
    <footer class="navbar text-white p-2 text-sm">
      <div class="container mx-auto flex justify-center items-center">
        <div>
          Powered by
          <a
            href="https://flotorch.ai?utm_source=flowtorch-repo"
            target="_blank"
            class="external-link"
            >FloTorch.ai<UIcon class="ml-[5px]" name="i-rivet-icons:link-external"
          /></a>
          For more information, contact us at
          <a href="mailto:info@flotorch.ai" class="external-link"
            >info@flotorch.ai<UIcon class="ml-[5px]" name="i-rivet-icons:link-external" /></a
          >
        </div>
      </div>
    </footer>
    </div>
  </div>
</template>

<style>
main.container {
  width: 100% !important;
  max-width: unset !important;
  min-width: unset !important;
  padding: 50px;
}

footer {
  position: fixed;
  bottom: 0;
  width: 100%;
}
</style>