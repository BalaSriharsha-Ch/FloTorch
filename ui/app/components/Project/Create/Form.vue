<script setup lang="ts">
import { useMutation, useQueryClient } from '@tanstack/vue-query';

import { v4 as uuidv4 } from 'uuid';

const props = defineProps<{
  config?: Record<string, any>
}>()

const { $emit } = useNuxtApp()

const uuid = uuidv4()

const currentStep = ref(1)
const totalSteps = 4

const state = reactive<Partial<ProjectCreate>>({
  prestep: props.config?.prestep || undefined,
  indexing: props.config?.indexing || undefined,
  retrieval: props.config?.retrieval || undefined,
  eval: props.config?.eval || undefined,
})

const isLastStep = computed(() => currentStep.value === totalSteps)


const queryClient = useQueryClient()

const { mutate } = useMutation({
  mutationFn: async (data: Record<string, any>) => {
    return useProjectCreate(data)
  },
  onSuccess: (data) => {
    queryClient.invalidateQueries({ queryKey: ['projects'] })
    navigateTo({
      name: "projects-id-validexperiments",
      params: {
        id: data.execution_id
      }
    })
  }
})

const nextStep = () => {
  $emit('closeTooltip');
  if (isLastStep.value) {
    const submitData = {
      name: state.prestep?.name,
      prestep: {
        region: state.prestep?.region,
        gt_data: state.prestep?.gt_data,
        kb_data: state.prestep?.kb_model === 'none' ? '' :  state.prestep?.kb_data,
        bedrock_knowledge_base : (state.prestep?.kb_model === 'default-upload' || state.prestep?.kb_model === 'none') ? false : true,
        knowledge_base : state.prestep?.kb_model === 'none' ? false : true

      },
      indexing: {
        chunking_strategy: state.indexing?.chunking_strategy || '',
        ...(state.indexing?.chunking_strategy.includes('fixed') ? { chunk_size: state.indexing?.chunk_size, chunk_overlap: state.indexing?.chunk_overlap } : {chunk_size:[],chunk_overlap:[]}),
        ...(state.indexing?.chunking_strategy.includes('hierarchical') ? { hierarchical_parent_chunk_size: state.indexing?.hierarchical_parent_chunk_size, hierarchical_child_chunk_size: state.indexing?.hierarchical_child_chunk_size, hierarchical_chunk_overlap_percentage: state.indexing?.hierarchical_chunk_overlap_percentage } : {
          hierarchical_parent_chunk_size : [],
          hierarchical_child_chunk_size : [],
          hierarchical_chunk_overlap_percentage : []
        }),
        vector_dimension: state.indexing?.vector_dimension || [],
        indexing_algorithm: state.indexing?.indexing_algorithm || '',
        embedding: state.indexing?.embedding?.map((pc) => {
          return {
            model: pc?.value,
            service: pc?.service,
            label: pc?.label
          }
        }) || [{
                "model": "",
                "service": "",
                "label": ""
            }]
      },
      retrieval: {
        n_shot_prompts: state.retrieval?.n_shot_prompts,
        knn_num: state.prestep?.kb_model === 'none' ? [] :  state.retrieval?.knn_num,
        temp_retrieval_llm: state.retrieval?.temp_retrieval_llm,
        retrieval: state.retrieval?.retrieval?.map((pc) => {
          return {
            model: pc.value,
            service: pc.service,
            label: pc.label
          }
        }),
        rerank_model_id: (state.prestep?.region === 'us-east-1' || state.prestep?.kb_model === 'none' ) ? ['none'] : state.retrieval?.rerank_model_id,
      },
      evaluation: {
        evaluation: [
          {
            service: state.eval?.service,
            embedding_model: state.eval?.ragas_embedding_llm,
            retrieval_model: state.eval?.ragas_inference_llm,
          }
        ],
      },
      n_shot_prompt_guide: state.retrieval?.n_shot_prompt_guide || {},
      guardrails: state.eval?.guardrails
    }
    mutate(submitData)
  } else {
    if(state.prestep.kb_model !== 'default-upload' && currentStep.value == 1){
      currentStep.value = currentStep.value + 2;
      kbFilesUploadedData.value = undefined; 
    }else{
    currentStep.value++

    }
  }
}

const previousStep = () => {
  $emit('closeTooltip');
   if(state.prestep.kb_model !== 'default-upload' && currentStep.value == 3){
      currentStep.value = currentStep.value - 2;
    }else{
    currentStep.value--
    }
}

const kbFilesUploadedData = ref();


// Add labels for steps
const steps = [
  { label: 'Data Strategy', icon: 'i-lucide-square-stack' },
  { label: 'Indexing Strategy', icon: 'i-lucide-layers' },
  { label: 'Retrieval Strategy', icon: 'i-lucide-file-search' },
  { label: 'Guardrails and Evaluation', icon: 'i-lucide-search' }
]
</script>



<template>
  <div>
    <div class="relative my-8">
      <!-- Progress bar -->
      <div class="absolute top-6 left-16 right-25 h-[2px] bg-gray-200">
        <div class="h-full bg-gray-600 transition-all duration-300 ease-in-out"
          :style="{ width: `${((currentStep - 1) / (totalSteps - 1)) * 100}%` }" />
      </div>

      <!-- Steps -->
      <div class="relative flex justify-between px-1 w-full">
        <div v-for="(step, index) in steps" :key="index" class="flex flex-col items-center gap-2"
          :class="{ 'text-gray-900': currentStep > index || currentStep === index + 1, 'text-gray-400': currentStep < index + 1 }">
          <div
            class="flex h-12 w-12 items-center justify-center rounded-full bg-white border-2 transition-all duration-300 ease-in-out text-lg"
            :class="[
              currentStep === index + 1 ? 'border-gray-900 !bg-gray-900 text-white' :
                currentStep > index ? 'border-gray-900 text-gray-900' :
                  'border-gray-200 text-gray-400'
            ]">
            <UIcon :name="step.icon" />
          </div>
          <div class="text-sm font-medium">{{ step.label }}</div>
        </div>
      </div>
    </div>
    <div v-if="currentStep === 1">
      <ProjectCreateDataStrategyStep @kbFilesUpload="(files) => kbFilesUploadedData = files" :kbFilesUploadedData="kbFilesUploadedData" :file-upload-id="uuid" v-model="state.prestep" :show-back-button="false" @next="nextStep" />
    </div>
    <div v-if="currentStep === 2">
      <ProjectCreateIndexingStrategyStep v-model="state.indexing" @previous="previousStep" @next="nextStep" />
    </div>
    <div v-if="currentStep === 3">
      <ProjectCreateRetrievalStrategyStep :kb-model="state.prestep?.kb_model" :region="state.prestep?.region" v-model="state.retrieval" @next="nextStep" @previous="previousStep" />
    </div>
    <div v-if="currentStep === 4">
      <ProjectCreateEvalStrategyStep :region="state.prestep?.region" :inferenceModel="state.retrieval?.retrieval?.map(model => model.value)" :embeddingModel="state.indexing?.embedding?.map(model => model?.value)" v-model="state.eval" @previous="previousStep" @next="nextStep" next-button-label="Submit" />
    </div>
  </div>
</template>
